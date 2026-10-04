# DateSnap Settings-to-Consumer Ledger

This ledger records every retained Settings control in the production UI after the non-production-code remediation. A control is retained only when a production runtime consumer exists. Presentation-only navigation state is listed separately because it does not claim to configure app behavior.

| Setting or state | Storage | Production writer | Production consumer | Observable effect | Verification |
|---|---|---|---|---|---|
| Enhanced interpretation (`IntelligencePolicy.userDefaultsKey`) | `UserDefaults` through `@AppStorage` | `AutomationSettingsView` | `IntelligencePolicy.enhancedInterpretationEnabled`; scan understanding pipeline | Enables supported on-device Apple Intelligence assistance for ambiguous flyers; deterministic extraction remains available | `EventUnderstandingPipelineTests/userDisabled()` and Xcode build |
| Settings navigation route (`SettingsState.pendingRoute`) | In-memory presentation state | `SettingsHubView`, `HelpFeedbackView`; Debug gallery | `SettingsClusterView` | Pushes a Settings destination and immediately clears the pending route | Settings navigation smoke test; not a behavioral preference |

## Removed controls

The following controls were removed because no production service or view model consumed them:

- scan profiles and smart-save modes;
- capture scope and AirDrop/shared-media monitoring;
- configurable confidence threshold and low-confidence draft routing;
- quick-extraction prompts, evening digest, and low-power throttling;
- screenshot auto-purge and purge windows;
- Face ID protection;
- global reminder presets, delivery routes, custom sounds, and static delivery simulation;
- duplicate plan name, price, renewal, and billing presentation state.

Alert offsets and destinations remain editable per event in the event-review workflow, where they are consumed directly by Calendar, Reminders, and local-notification services. Subscription state remains sourced from StoreKit through the subscription service and is intentionally not duplicated in `SettingsState`.

## Release rule

Any future Settings control must identify its persisted storage, production consumer, failure behavior, and automated verification in this ledger before it can ship. A toggle that only changes its own visual state is not release-ready.
