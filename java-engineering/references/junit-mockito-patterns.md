# JUnit 5 & Mockito Patterns

Write fast, isolated, readable Spring Boot tests — the right test slice, the cheapest mock strategy that isolates, and behavior-focused assertions.

---

## Overview

Spring Boot testing is a set of deliberate trade-offs: `@SpringBootTest` loads the full context and proves the most, but starts slowly; test slices (`@WebMvcTest`, `@DataJpaTest`) load a fraction of it and run 10–100x faster at the cost of needing careful mocking. The philosophy here is fast feedback without sacrificing isolation — pick the narrowest slice that still exercises the real collaboration under test, mock only what has to cross a boundary, and assert on observable behavior rather than internal call counts. A single poorly written test (flaky, slow, or asserting on implementation detail) erodes CI trust faster than a missing test does.

## Core Concepts

**Test behavior, not implementation.** Assert on HTTP status, return values, and observable side effects — not on internal state or how many times a collaborator's method was called. A refactor that preserves behavior shouldn't break a test that only real behavior change should break.

**One test verifies one concept.** If a test name needs "and" to describe it, it's testing two things — split it. Narrow tests localize failures; broad tests require debugging to find out which assertion actually failed.

**Arrange → Act → Assert, visibly.** Every test has three phases, separated by blank lines. This isn't cosmetic — a test where setup, action, and assertion blur together is harder to review and more likely to hide an accidental assertion-before-action bug.

**Test slices earn their speed by loading less, so use the narrowest one that's still honest.** `@WebMvcTest` loads only the web layer (fast, ~100ms) and requires mocking every service dependency. Plain Mockito unit tests (`@ExtendWith(MockitoExtension.class)`) load no Spring context at all (~10ms). `@DataJpaTest` loads the JPA layer against a real (or Testcontainers) database (~500ms) — the only way to actually test a query. `@SpringBootTest` loads everything (~5s+) and should be reserved for true end-to-end flows, not routine coverage.

**Isolate at the transaction boundary, not by manual cleanup.** `@Transactional` on a database test rolls back all changes after the test method returns, which eliminates test-ordering dependencies for free. Manual `@AfterEach` cleanup is a symptom that isolation was designed in after the fact.

**Choose the cheapest mock strategy that gives you the isolation you need.** `@MockitoBean` replaces a bean inside a Spring context (`@WebMvcTest`, `@SpringBootTest`); `@Mock`/`@InjectMocks` needs no context at all for a pure unit test; a hand-written fake (an in-memory `Map`-backed implementation) is the right choice when a collaborator is stateful enough that stubbing every call obscures the test's intent. If a `when(...)` setup block is longer than the behavior it's testing, that's the signal mocking is fighting you — reach for a fake or `@SpringBootTest` with real beans instead of mocking five-plus dependencies. **Version note:** `@MockBean`/`@MockBeans` (the older `org.springframework.boot.test.mock.mockito` annotations) were deprecated in Spring Boot 3.4 and removed in Spring Boot 4.0 (GA November 2025) — `@MockitoBean`/`@MockitoSpyBean` (`org.springframework.test.context.bean.override.mockito`, Spring Framework 6.2+) are the current replacement and are not a strict drop-in (check the migration notes for a project still on the 3.4–3.5 line before assuming identical behavior).

**Parameterized tests should match the source to the shape of the data.** `@ValueSource` for one primitive per case, `@CsvSource` for small literal tuples, `@MethodSource` for anything requiring constructed objects (`BigDecimal`, entities) — always paired with a descriptive `name = "..."` template so a failure is self-explanatory without opening the test file.

**Architecture rules belong in a test, not a review comment.** ArchUnit encodes layer-dependency and naming-convention rules as executable assertions, so "services must not access controllers" fails CI the moment it's violated instead of surfacing three review cycles later.

**The inline mock maker is the default, not an opt-in.** Since Mockito 5, `mockito-core` ships with the inline mock maker as the default (the old subclass-based maker and its `mockito-inline` add-on are no longer needed) — mocking final classes/methods and `Mockito.mockStatic(...)` for static methods work out of the box. If a project still declares a separate `mockito-inline` dependency or a `MockMaker` config file to enable this, it's carrying obsolete setup; reach for `mockStatic` sparingly regardless — it's a sign a static dependency should probably be injected instead.

## Decision Framework

| Question | Choose | Because |
|---|---|---|
| Testing HTTP request/response contract for a controller? | `@WebMvcTest` + `MockMvc`, mock the service | Fast; exercises the real web layer without the rest of the app |
| Testing business logic with no Spring wiring needed? | `@ExtendWith(MockitoExtension.class)`, `@Mock`/`@InjectMocks` | Fastest possible; no context startup at all |
| Testing a repository query (need real SQL semantics)? | `@DataJpaTest` + `TestEntityManager` | Only way to catch a query bug — mocking the repository proves nothing about the query |
| Testing a full request→DB→response flow, or a batch job? | `@SpringBootTest` (+ Testcontainers for a real DB) | Reserve for genuine integration/E2E; too slow for routine coverage |
| Mocking a dependency that must participate in Spring DI? | `@MockitoBean` (Spring Boot 4.0+; `@MockBean` if the project is still on Boot ≤3.5) | Only mechanism that replaces a bean inside the context |
| Mocking a dependency with 5+ collaborators to stub? | Refactor the service, or use a fake / `@SpringBootTest` with real beans | Heavy mocking setups usually indicate a design smell, not a testing one |
| Choosing a parameterized source? | `@ValueSource` (primitives) / `@CsvSource` (small tuples) / `@MethodSource` (constructed objects) | Match the source to the data's shape; `@MethodSource` + `name=` for anything non-trivial |
| Asserting an async/eventual result? | Awaitility's `await().atMost(...).until(...)` | `Thread.sleep()` is slow and flaky; polling with a timeout is deterministic |

## Workflow

1. **Identify the layer under test** and pick the slice from the table above; read the class under test and its collaborators before writing anything.
2. **Choose the mock strategy** — the cheapest one that still isolates (see Core Concepts).
3. **Write three visible phases** — Arrange, Act, Assert, separated by blank lines.
4. **Name for the scenario**: `test{Method}_{Condition}_{Expectation}()` — e.g. `testGetProductById_WithInvalidId_ThrowsException()`, never a bare `test()`.
5. **Build test data from factories**, never inline setter chains — a static factory with sensible defaults plus targeted overloads, or a fluent builder once an entity has many optional fields.
6. **Assert on the result or a critical side effect**, not on every internal call — `verify()` is for side effects that matter to the contract, not a substitute for asserting the return value.
7. **Verify against the Quality Checklist** before committing.

## Patterns

### Controller slice (`@WebMvcTest`)

```java
@WebMvcTest(ProductController.class)
class ProductControllerTest {
    @Autowired private MockMvc mockMvc;
    @MockitoBean private ProductService productService;   // @MockBean on Spring Boot ≤3.5

    @Test
    void testGetProductById_ReturnsProductWithOkStatus() throws Exception {
        // Arrange
        Product product = TestEntityFactory.createProduct("Laptop", new BigDecimal("999.99"));
        when(productService.getProductById(1L)).thenReturn(product);

        // Act & Assert
        mockMvc.perform(get("/api/products/1"))
            .andExpect(status().isOk())
            .andExpect(jsonPath("$.name").value("Laptop"));
    }
}
```

### Service unit test (`@ExtendWith(MockitoExtension.class)`)

```java
@ExtendWith(MockitoExtension.class)
class ProductServiceTest {
    @Mock private ProductRepository productRepository;
    @InjectMocks private ProductServiceImpl productService;

    @Test
    void testGetProductById_WithInvalidId_ThrowsException() {
        // Arrange
        when(productRepository.findById(99L)).thenReturn(Optional.empty());

        // Act & Assert
        assertThatThrownBy(() -> productService.getProductById(99L))
            .isInstanceOf(EntityNotFoundException.class)
            .hasMessageContaining("not found");
    }
}
```

### Repository slice (`@DataJpaTest`)

```java
@DataJpaTest
class ProductRepositoryTest {
    @Autowired private ProductRepository productRepository;
    @Autowired private TestEntityManager entityManager;

    @Test
    void testFindById_WithValidId_ReturnsProduct() {
        // Arrange
        Product product = TestEntityFactory.createProduct("Tablet", new BigDecimal("349.99"));
        entityManager.persistAndFlush(product);

        // Act
        Optional<Product> result = productRepository.findById(product.getId());

        // Assert
        assertThat(result).isPresent()
            .hasValueSatisfying(p -> assertThat(p.getName()).isEqualTo("Tablet"));
    }
}
```

### Integration test with Testcontainers

Prefer `@ServiceConnection` over manual `@DynamicPropertySource` wiring — it auto-configures the datasource/Redis connection properties from the container, removing a whole class of "forgot to wire a property" test bugs:

```java
@SpringBootTest
@Testcontainers
class OrderIntegrationTest {
    @Container
    @ServiceConnection
    static PostgreSQLContainer<?> postgres = new PostgreSQLContainer<>("postgres:16-alpine");

    @Autowired private OrderRepository orderRepository;

    @Test
    @Transactional
    void testCreateOrder_PersistsAndReturnsId() {
        // real database, real driver, rolled back after the test via @Transactional
    }
}
```

### Test data factories

```java
public class TestEntityFactory {
    public static Product createProduct(String name, BigDecimal price) {
        Product product = new Product();
        product.setName(name);
        product.setPrice(price);
        return product;
    }
}
// Complex entities: switch to a fluent builder once optional fields multiply.
Order order = new OrderBuilder().withStatus(OrderStatus.SHIPPED).withTotal(new BigDecimal("150.00")).build();
```

### Parameterized tests with `@MethodSource`

```java
@ParameterizedTest(name = "price={0}, quantity={1} → valid={2}")
@MethodSource("orderValidationCases")
void testValidateOrder_WithVariousInputs(BigDecimal price, int quantity, boolean shouldBeValid) {
    assertThat(orderService.isOrderValid(price, quantity)).isEqualTo(shouldBeValid);
}

static Stream<Arguments> orderValidationCases() {
    return Stream.of(
        Arguments.of(new BigDecimal("10.00"), 1, true),
        Arguments.of(new BigDecimal("-5.00"), 1, false),
        Arguments.of(new BigDecimal("10.00"), 0, false)
    );
}
```

### ArchUnit layer rules as executable tests

```java
@AnalyzeClasses(packages = "com.example.ordersystem")
class ArchitectureTest {
    @ArchTest
    static final ArchRule services_should_not_access_controllers =
        noClasses().that().resideInAPackage("..service..")
            .should().accessClassesThat().resideInAPackage("..controller..");

    @ArchTest
    static final ArchRule repositories_named_correctly =
        classes().that().resideInAPackage("..repository..")
            .should().haveSimpleNameEndingWith("Repository");
}
```

## Pitfalls / Anti-Patterns

| Symptom | Cause | Fix |
|---|---|---|
| Test suite takes minutes to run | `@SpringBootTest` used for routine coverage | Use `@WebMvcTest`/`@DataJpaTest`/plain Mockito; reserve `@SpringBootTest` for true integration |
| Test breaks on every internal refactor even though behavior is unchanged | Asserting on mock call counts instead of results | Assert on return value or one critical side effect, not every collaborator interaction |
| Service test has 6 `@Mock` fields and a wall of `when(...)` | Service has too many responsibilities | Refactor the service, or drop to `@SpringBootTest` with real beans instead of mocking everything |
| Tests pass individually, fail when run together | Static/shared mutable state, or MDC/cache not cleared between tests | Fresh state per test via `@BeforeEach`; clear caches; avoid static fields |
| Flaky test that "usually" passes | `Thread.sleep()` racing an async operation | Use Awaitility's `await().atMost(...).until(...)` polling instead |
| Test asserts framework behavior, not app logic | e.g. asserting Spring returns 400 for malformed JSON | Test your validation/business logic, not the framework's own guarantees |
| `LazyInitializationException` only in tests, not in the running app | `@DataJpaTest` test reads a lazy relationship after the transaction/session closed | Use `@EntityGraph`/fetch join in the query under test, same as production code |

## Quality Checklist

- [ ] Arrange → Act → Assert, with blank-line separation, in every test
- [ ] Test name follows `test{Scenario}_{Condition}_{Expectation}()` — no bare `test()`/vague names
- [ ] Narrowest correct test slice used — `@WebMvcTest`/`@DataJpaTest`/plain Mockito before `@SpringBootTest`
- [ ] `@MockitoBean` (Boot 4.0+) or `@MockBean` (Boot ≤3.5 — check the project's actual Spring Boot generation first) used only where a bean must participate in the Spring context; plain `@Mock` elsewhere
- [ ] Test data comes from factories/builders, never hardcoded inline construction
- [ ] No `Thread.sleep()` — async assertions use Awaitility
- [ ] AssertJ fluent assertions (`.isEqualTo()`, `.hasSize()`) over JUnit's `assertEquals`
- [ ] Database tests roll back via `@Transactional`, not manual cleanup
- [ ] Parameterized tests use `@MethodSource` with a descriptive `name = "..."` template for non-trivial data
- [ ] ArchUnit (or equivalent) enforces layer boundaries as a test, not just a review convention
- [ ] No test mocks 5+ dependencies without a documented reason (refactor candidate otherwise)
- [ ] Testcontainers integration tests use `@ServiceConnection` rather than manual `@DynamicPropertySource` wiring
