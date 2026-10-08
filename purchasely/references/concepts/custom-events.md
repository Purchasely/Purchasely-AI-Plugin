# Custom Events — Universal Patterns

Applies to: **native iOS SDK 6.2.0+ and native Android SDK 6.2.0+ only**. The React Native, Flutter and Cordova bridges do not expose `emit` yet: do not promise it there.

A **custom event** is a business event of your own app (`recipe_viewed`, `checkout_started`, `onboarding_completed`) that you hand to Purchasely. The SDK can then do two independent things with it:

- **Send it** to Purchasely, to measure it and to build audiences on it (only if the event is declared in the Console).
- **Open a campaign** that is linked to it in the Console.

An event can be sent and open nothing, open a campaign and be sent nowhere, do both, or do neither. Nothing in the call tells you which.

## Emit an event

### iOS (Swift)

```swift
Purchasely.emit(name: "recipe_viewed", properties: ["recipe_id": 42, "title": "Ratatouille"])
Purchasely.emit(name: "checkout_started")
```

### iOS (Objective-C)

```objc
[Purchasely emitWithName:@"recipe_viewed" properties:@{@"recipe_id": @42}];
```

### Android (Kotlin)

```kotlin
Purchasely.emit("recipe_viewed", mapOf("recipe_id" to 42, "title" to "Ratatouille"))
Purchasely.emit("checkout_started")
```

### Android (Java)

`emit` is `@JvmStatic` and `@JvmOverloads`, so both forms work from Java:

```java
Purchasely.emit("recipe_viewed", Map.of("recipe_id", 42));
Purchasely.emit("checkout_started");
```

Signatures (source of truth): iOS `emit(name: String, properties: [String: Any] = [:])`, Android `emit(name: String, properties: Map<String, Any?> = emptyMap())`. The call returns at once, reports nothing back and never throws. It is safe to call before `start()`. On Android, an event emitted before the configuration is loaded has nothing to match against and is simply not sent.

## Declare the event in the Console

Open **Targeting > Events** in the Console.

1. **Properties tab.** Declare each property once for the app: a name and a type (`string`, `int`, `float`, `bool`, `date` or `array of strings`). You then link it to each event that sends it, and two events can share one property. Rename, retype or delete of a property applies to every event that uses it.
2. **New Custom Event.** Type the name (it must match what the app sends exactly). Optionally pick a color and add tags. Link an existing property, or create one in the dialog (it joins the Properties tab when you save).

The SDK sends **only the event names declared in the Console**. The match is exact: case and spaces count, and the SDK never trims or changes the name. `"Recipe Viewed"` and `"recipe_viewed"` are two different events. An undeclared event is ignored, with no error: a typo is silence.

## Properties

- **Android** accepts these value types: `Int`, `Long`, `Float`, `Double`, `Boolean`, `String`, `Date` and a list of `String`.
- **iOS** validates no type itself. Dates are sent as ISO 8601 strings. A value that cannot be serialized (`NaN`, infinity, a custom object) is dropped alone, with a warning in the logs, and the rest of the event is sent normally.
- On both platforms the declared property type in the Console decides how the backend reads the value. Keep each property to one type.
- Property keys travel as given, nested apart from the Purchasely context: a property named `user_id` cannot overwrite a Purchasely field.

## What each event carries

- Your **user attributes** and the **built-in attributes** as they were at the moment of the call.
- Two built-in attributes are new and built from custom events, to target audiences on them:
  - `ply_custom_events_tracked`: for each event name, how many events of that name the SDK sent.
  - `ply_custom_events_last_tracked`: for each event name, the time of the last one.
- Both are maps keyed by event name, and count what was sent, not what your code called. An undeclared or consent-blocked event moves neither map. The event itself carries the count as it stood before its own increment.
- An event you emit from code carries no screen context, even while a paywall is on screen. An event fired from a screen (`track_event`, below) carries the screen context.

## Consent

When the user refuses the `analytics` purpose, the SDK sends no new custom event. Revoking `analytics` also clears custom events still waiting in the queue (Android). Campaign triggers use a different purpose (`campaigns`): a refused `analytics` purpose does not stop the trigger path. See [privacy-settings.md](privacy-settings.md).

## Delivery

Custom events have their own queue and their own retries, separate from the SDK's own events. They never reach `PLYEventDelegate` (iOS) or the event listener (Android): your app emitted them, so the SDK does not hand them back. Existing Purchasely events keep their content and delivery. See [analytics-integration.md](analytics-integration.md).

## Trigger a campaign from a custom event

There are two ways to start:

- On the event card in **Targeting > Events**, click **Map with a new campaign**. The Console opens a new campaign with the event as the trigger.
- In a campaign, turn on the **When** section. The **Trigger** list holds `APP_STARTED`, the SDK events that can be triggers, and your custom events.

When the event fires, the SDK opens the campaign screen. If you select several events, the campaign starts when one of them fires. The same rules as the app-launch (`APP_STARTED`) campaign apply: schedule dates, capping (frequency, impression cap), exposure window, and the `campaigns` consent purpose. `allowCampaigns` also applies: when it is `false`, the SDK keeps the campaign until the app sets it to `true` again. A custom event never opens the campaigns of a Purchasely event with the same name: a custom event named `APP_STARTED` does not open the startup campaigns. An SDK older than 6.2.0 ignores the campaigns that use a custom event. See [campaigns.md](campaigns.md).

### Filter on properties

Under **Filters**, **Filter on properties** starts the campaign only when the event properties match. Each condition has a property, an operation and, for most operations, a value. Use **AND/OR** to join conditions in a group, and **Add condition group** to add a group.

| Type | Operations |
|---|---|
| `string` | equals to, is different from, contains, starts with, ends with, is one of |
| `int` | equals to, is different from, is greater than, is greater than or equal to, is less than, is less than or equal to, is between |
| `bool` | is true, is false, is true or not set, is false or not set |

## The `track_event` screen action

A Screen button can send one of your custom events with the `track_event` action, configured in the Screen Composer: **On tap > Action > Track event**, then **Custom event**. You can add an optional **Second action** (for example Close/Back). The event carries the context of the screen: presentation, placement, audience, A/B test and variant, campaign, flow and step.

- Use it to measure a **success KPI** for a campaign, a flow or an A/B test (a sign-up, a finished onboarding), beyond the purchases the SDK already counts.
- It **cannot be intercepted**: the interceptor never sees it, so the app cannot cancel it.
- It never blocks the actions next to it. A button that tracks an event and then purchases still closes the paywall after the purchase.
- You set no property values in the action: it carries the event name only. An SDK older than 6.2 ignores the action and sends nothing.
- It carries the event name only, no properties. An empty `event_name` logs a warning and tracks nothing.
- The event name must be declared in the Console like any custom event.

See [paywall-actions.md](paywall-actions.md).

## Measure the event in an experiment

The **Primary KPI** step of an experiment lists your custom events: pick one as the metric that decides the winner. A Local experiment can also target custom events in its **When** section, like a campaign trigger.

## Troubleshooting: the event is not visible

1. **The name is not declared** in the Console. Declare it, then restart the app so the SDK fetches the new configuration.
2. **The name does not match.** Compare case and spaces character by character with the Console declaration.
3. **The `analytics` purpose is refused** for this user. No new custom event is sent. Check `revokeDataProcessingConsent` calls.
4. **The SDK is older than 6.2.0**, or the app uses a React Native, Flutter or Cordova bridge (still on native 6.0.x). `emit` does not exist there.
5. **The event arrives but no campaign opens.** The campaign is a separate path: check the campaign trigger, dates, capping, exposure and the `campaigns` purpose.
6. **The event is missing from `PLYEventDelegate` / the event listener.** This is expected: custom events never reach it.

Enable debug logs ([troubleshooting/debug-mode.md](../troubleshooting/debug-mode.md)). On Android, the SDK logs a warning when an event is dropped because its name is not declared.

## See also

- [campaigns.md](campaigns.md): campaign triggers, capping, exposure
- [paywall-actions.md](paywall-actions.md): the `track_event` action
- [user-attributes-targeting.md](user-attributes-targeting.md): built-in attributes for audiences
- [privacy-settings.md](privacy-settings.md): the `analytics` and `campaigns` purposes
- [analytics-integration.md](analytics-integration.md): what reaches the event delegate
- Official guide: https://docs.purchasely.com/docs/custom-events
