# Cursor Rules

Follow the existing project architecture strictly.

Do not:
- introduce unnecessary abstractions
- generate extremely large files
- replace Riverpod with other state management solutions
- create excessive boilerplate
- overcomplicate UI

Prefer:
- small reusable widgets
- readable code
- modern Flutter best practices
- feature-based structure
- maintainable architecture

When generating UI:
- prioritize clean spacing
- prioritize collectible imagery
- keep layouts visually balanced
- avoid cluttered designs

Before generating new architecture patterns:
- follow the existing project structure first

For MVP:
- prioritize shipping features quickly
- avoid premature optimization

## Backend Integration Rules

- Keep API clients inside feature/data or core/network layers
- Do not call HTTP clients directly from widgets
- Prefer repository abstractions
- Preserve Riverpod boundaries
- Avoid coupling UI to eBay response models
- Create app-specific domain models/adapters
- Keep mock data available for preview/testing