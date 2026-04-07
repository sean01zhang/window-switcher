# Architecture Boundaries

This repository uses a small set of object roles. The goal is to keep responsibilities clear and prevent state, system APIs, and UI logic from bleeding into each other.

## Models

- Pure data only.
- No `@Observable`, `@MainActor`, `Task`, `NSWorkspace`, file I/O, AX calls, or app lifecycle logic.
- Fine for enums, structs, decoding types, config data, identifiers, and values.
- Small side-effect-free derived data is also fine when it stays obviously tied to the value itself, for example `Window.fullyQualifiedName`.
- If it could be serialized, compared, or passed around without the app running, it probably belongs here.

## Clients

- Boundary adapters to external systems.
- Wrap AppKit, system frameworks, disk, process launching, permissions, screenshots, workspace APIs, and similar dependencies.
- Focus on "do the operation" rather than "own shared UI state".
- Prefer stateless clients, or narrowly stateful clients when caching or observation is inherent to the boundary.

## Stores

- Shared app or domain state.
- Long-lived objects observed by multiple parts of the app.
- Usually built on top of one or more clients.
- Own "current state of X for the app", not "current UI interaction for one screen".
- Use a store when app flow, menu UI, onboarding, or multiple views need one shared source of truth.

## ViewModels

- View-specific or flow-specific state and behavior.
- Own selection, search text, temporary UI caches, local async tasks, presentation ordering, and screen interaction logic.
- Scoped to one scene, window, or view tree.
- Can depend on models, clients, and stores.
- Should not become the app-wide source of truth.

## Views

- Render UI and forward user intent.
- Keep decision logic minimal.
- Avoid direct system side effects unless the effect is truly view-local.
- Prefer calling into a view model or store rather than embedding app behavior in the view.

## App, AppDelegate, and Presenters

- Composition root and app flow.
- Construct long-lived dependencies.
- Decide ownership and lifetime.
- Coordinate transitions between app-wide objects.
- Good place for permission gating, onboarding presentation, startup wiring, and other application-level behavior.

## Quick Classification Rules

- "Is this plain data?" -> Model
- "Is this external I/O?" -> Client
- "Is this shared state across multiple screens or app flow?" -> Store
- "Is this only for one UI surface?" -> ViewModel

## Stable Examples

- A permission status enum is a model.
- A thin wrapper over `SMAppService`, `NSWorkspace`, Accessibility APIs, or ScreenCaptureKit is a client.
- An installed-app index that caches results from the filesystem can still be a client if the cache is part of that boundary.
- Shared permission state used by onboarding, app flow, and menu UI is a store.
- Menu-only toggle state or switcher-session search state is a view model.

## Review Checklist

- If a type touches system APIs directly, make sure it is not pretending to be a model.
- If a type is observable, ask whether that state is shared app state or only view-scoped state.
- If a type exists only to support one surface, prefer a view model over a store.
- If a helper is pure and tiny, prefer placing it near the type it describes instead of creating a standalone utility file.
- If a client becomes stateful, make sure that state is naturally tied to the underlying boundary rather than being unrelated UI state.

## Naming Guidance

- Use `Client` for external-system boundaries.
- Use `Store` for shared app/domain state.
- Use `ViewModel` for UI-scoped state and interaction logic.
- Avoid using `Service` unless the type does not clearly fit `Client`, `Store`, or `ViewModel`.
