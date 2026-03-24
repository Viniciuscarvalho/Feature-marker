# React Stack Patterns

Conventions and patterns for React/Node.js projects. Loaded when `platform-context.json` reports `primary_platform=nodejs` with a React-related subtype.

## Architecture

### Component/Hook/Service Layering

```
src/
├── components/
│   ├── ui/                # Shared UI primitives (Button, Input, Modal)
│   └── {feature}/         # Feature-specific components
│       ├── {Feature}.tsx
│       ├── {Feature}.test.tsx
│       └── use{Feature}.ts  # Feature hook
├── hooks/                 # Shared custom hooks
├── services/              # API clients, external service wrappers
├── lib/                   # Utilities, helpers, constants
├── types/                 # Shared TypeScript types/interfaces
└── app/ or pages/         # Route definitions (Next.js / React Router)
```

### Key Principles

- Components are functional with hooks — no class components
- Custom hooks extract logic from components (`use{Feature}`)
- Services handle API communication — components never call `fetch` directly
- Types are co-located when feature-specific, shared in `types/` when cross-cutting

## Testing Patterns

### React Testing Library

```tsx
import { render, screen, waitFor } from "@testing-library/react";
import userEvent from "@testing-library/user-event";
import { FeatureComponent } from "./FeatureComponent";

describe("FeatureComponent", () => {
  it("renders the expected content", () => {
    render(<FeatureComponent />);
    expect(screen.getByText("Expected Text")).toBeInTheDocument();
  });

  it("handles user interaction", async () => {
    const user = userEvent.setup();
    render(<FeatureComponent />);
    await user.click(screen.getByRole("button", { name: /submit/i }));
    await waitFor(() => {
      expect(screen.getByText("Success")).toBeInTheDocument();
    });
  });
});
```

### Query Priority

1. `getByRole` — accessible queries (preferred)
2. `getByLabelText` — form elements
3. `getByText` — visible text
4. `getByTestId` — last resort

### Mocking

- Mock API calls with `msw` (Mock Service Worker) or `vi.mock`/`jest.mock`
- Mock hooks with `vi.mock('./useFeature')`
- Avoid mocking implementation details — test behavior

## State Management

| Scope           | Solution                            |
| --------------- | ----------------------------------- |
| Component-local | `useState`, `useReducer`            |
| Feature-shared  | Custom hook with context            |
| Global (client) | Zustand, Jotai, or React Context    |
| Server state    | TanStack Query (React Query) or SWR |

## File Naming

| Type      | Convention        | Example                |
| --------- | ----------------- | ---------------------- |
| Component | `PascalCase.tsx`  | `UserProfile.tsx`      |
| Hook      | `camelCase.ts`    | `useUserProfile.ts`    |
| Service   | `camelCase.ts`    | `userService.ts`       |
| Test      | `{name}.test.tsx` | `UserProfile.test.tsx` |
| Types     | `camelCase.ts`    | `user.types.ts`        |
| Utils     | `camelCase.ts`    | `formatDate.ts`        |

## Error Handling

- Use Error Boundaries for component-level error catching
- Handle async errors in hooks with try/catch
- Show user-friendly error messages — log technical details to console
- Use `isError` / `error` from TanStack Query for server state errors
