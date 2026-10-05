# ADR 0002: Live Gemini Model Discovery, Selection, and Gateway Registry

## Status
Accepted

## Context
Per Blueprint §24 and Agent.md §4, model names must not be hardcoded from memory or assumed. The system must query the official Google Gemini `ListModels` API using the configured integration key, discover available models supporting content generation, record actual discovery results, and select models via dynamic configuration and a model registry.

Furthermore, Agent.md §4 requires verifying that requests actually reach the provider via an actual live test, while strictly masking the API key in all outputs and persisted files.

## Discovery Results (Executed: 2026-10-05)
A live request to the Google Generative Language API endpoint (`https://generativelanguage.googleapis.com/v1beta/models`) was performed.
- Total models discovered: 50.
- Models supporting `generateContent`:
  - `gemini-2.5-flash`
  - `gemini-2.5-pro`
  - `gemini-flash-latest`
  - `gemini-3.5-flash`
  - `gemini-3.7-flash`
  - `gemini-3.8-flash`
  - and associated specialized models.
- When querying `gemini-2.5-flash`, the API returned status 404 with official deprecation notice:
  *"This model models/gemini-2.5-flash is no longer available to new users. Please update your code to use models/gemini-3.8-flash for the latest features and improvements."*
- Verification execution against `models/gemini-3.8-flash` succeeded with status 200, successfully generating content (`PONG`).

## Decision
1. **Primary Model Selection:** We select `gemini-3.8-flash` as the default text/reasoning model for the Google Gemini adapter.
2. **Model Registry & Config:** Model names are resolved dynamically via environment variables (`AI_PRIMARY_MODEL`) and managed inside a centralized `ModelRegistry` catalog. No application domain code hardcodes model identifiers.
3. **Gateway Abstraction:** Domain code interacts solely with `AIGateway` capability interfaces (`generateText`, `extractStructuredData`, `embedText`), remaining agnostic to the underlying provider and model IDs.

## Consequences
- **Positive:** Complies with Google's active 2026 API standards and deprecation directives.
- **Positive:** Zero vendor/model lock-in in domain services.
- **Positive:** Dynamic fallback enabled if a model or provider experiences degradation.
