# Python Stack Patterns

Conventions and patterns for Python projects. Loaded when `platform-context.json` reports `primary_platform=python`.

## Architecture

### Project Structure

```
src/{package_name}/
├── api/               # Route handlers (FastAPI) or views (Django)
│   └── {resource}.py
├── models/            # Data models (Pydantic, SQLAlchemy, Django ORM)
│   └── {entity}.py
├── services/          # Business logic
│   └── {domain}_service.py
├── repositories/      # Data access layer (optional, for Clean Architecture)
│   └── {entity}_repository.py
└── utils/             # Shared utilities
    └── {domain}.py

tests/
├── conftest.py        # Shared fixtures
├── test_{module}.py   # Test files mirror source structure
└── {subdirectory}/
    └── test_{file}.py
```

### Key Principles

- Type hints on all function signatures
- Pydantic models for request/response validation
- Dependency injection via FastAPI `Depends()` or constructor injection
- Separation of API handlers, business logic (services), and data access

## Testing Patterns

### pytest

```python
import pytest
from {package}.services.user_service import UserService

@pytest.fixture
def user_service(mock_repository):
    return UserService(repository=mock_repository)

class TestUserService:
    def test_creates_user_with_valid_data(self, user_service):
        result = user_service.create(name="Alice", email="alice@test.com")
        assert result.name == "Alice"
        assert result.id is not None

    def test_raises_on_duplicate_email(self, user_service, mock_repository):
        mock_repository.find_by_email.return_value = existing_user
        with pytest.raises(DuplicateError):
            user_service.create(name="Bob", email="existing@test.com")

    @pytest.mark.parametrize("email", ["", "invalid", "no@tld"])
    def test_rejects_invalid_emails(self, user_service, email):
        with pytest.raises(ValidationError):
            user_service.create(name="Test", email=email)
```

### Fixtures

- Define shared fixtures in `conftest.py`
- Use `@pytest.fixture` for setup/teardown
- Use `@pytest.mark.parametrize` for data-driven tests
- Use `unittest.mock.patch` or `pytest-mock` for mocking

## Type Hints

```python
from typing import Optional
from pydantic import BaseModel

class UserCreate(BaseModel):
    name: str
    email: str
    role: Optional[str] = None

def create_user(data: UserCreate) -> User:
    ...
```

## Error Handling

```python
# Define domain exceptions
class DomainError(Exception):
    """Base exception for domain errors."""

class NotFoundError(DomainError):
    def __init__(self, entity: str, id: str):
        super().__init__(f"{entity} not found: {id}")

class UnauthorizedError(DomainError):
    pass
```

## File Naming

| Type   | Convention         | Example                |
| ------ | ------------------ | ---------------------- |
| Module | `snake_case.py`    | `user_service.py`      |
| Test   | `test_{module}.py` | `test_user_service.py` |
| Model  | `snake_case.py`    | `user.py`              |
| Config | `snake_case.py`    | `settings.py`          |
