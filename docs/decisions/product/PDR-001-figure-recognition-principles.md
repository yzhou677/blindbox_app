# PDR-001: Figure Recognition Principles

## Status

Accepted.

## Product Vision

> Shelfy is not trying to understand an entire display shelf.

Shelfy helps collectors identify one intended collectible at a time, even when
that collectible is part of a much larger display. A real collector's photo may
contain many figures, shelves, reflections, decorations, and other objects. That
context is normal. Shelfy should reduce the effort of identifying the
collectible the user cares about without turning the experience into an attempt
to interpret everything visible.

The measure of success is not how many objects Shelfy can process at once. It is
whether identifying one intended collectible feels simple, trustworthy, and
under the collector's control.

## 1. Recognition Is Intentional, Not Automatic

### Principle

Recognition always begins with one intended collectible. Shelfy does not attempt
to recognize every collectible or object in a photograph.

### Why

A display shelf contains more visual information than the collector needs for a
single action. Treating every visible object as a recognition target creates
noise, uncertainty, and unnecessary decisions. Intent gives the experience a
clear purpose.

### Expected User Behavior

The collector takes or chooses a photograph because they want to identify one
particular collectible within it.

### Product Implications

Every recognition attempt must have one intended subject. Other visible
collectibles remain context, not additional recognition tasks.

## 2. Automatic Selection Is Only a Suggestion

### Principle

Shelfy may suggest the most likely intended subject, but the suggestion is never
an assertion about the user's intent.

### Why

Only the collector knows which figure they meant to identify. Even a visually
reasonable selection can be the wrong choice for that moment. Trust requires
Shelfy to distinguish a helpful guess from a user decision.

### Expected User Behavior

The collector may accept the suggested subject or choose another collectible
visible in the same photograph.

### Product Implications

Shelfy must not insist that its initial selection is correct. Changing the
selected subject should feel like a normal part of the experience, not error
recovery.

## 3. One Photograph Can Be Reused

### Principle

A photograph is reusable context. Recognition still happens one collectible at
a time, but the same photograph may support multiple recognition attempts.

### Why

Collectors commonly photograph figures where they are displayed. Requiring a
new photograph for every figure adds effort without adding meaningful intent.
The photograph and the selected subject are separate choices.

### Expected User Behavior

After identifying one collectible, the collector may return to the same
photograph and select another collectible without retaking it.

### Product Implications

Completing one recognition must not imply that the photograph has been fully
processed or exhausted. Shelfy should preserve the collector's ability to make
another intentional selection from it.

## 4. Figure Recognition Comes Before Series Recognition

### Principle

Shelfy recognizes an individual Figure first. Series information follows from
the recognized Figure.

### Why

The object in front of the collector is a specific figure, not an abstract
Series. Starting with the individual keeps the result precise and avoids
presenting broad Series familiarity as exact recognition.

### Expected User Behavior

The collector asks, in effect, “Which figure is this?” Shelfy may then use that
answer to show the figure's Series context.

### Product Implications

The product must not treat a likely Series as a substitute for identifying the
Figure. It must not search for or claim recognition of an entire Series as the
primary result.

## 5. Guidance Should Happen Before Failure

### Principle

When practical, Shelfy should help the collector create a usable recognition
attempt before the photograph is captured.

### Why

Preventing a foreseeable failure is kinder than explaining it afterward. Simple
guidance reduces frustration and makes recognition feel cooperative rather than
judgmental.

### Expected User Behavior

The collector may adjust distance, framing, focus, or subject placement in
response to timely guidance such as no collectible detected, subject too small,
subject too blurry, or poor framing.

### Product Implications

Guidance should be clear, actionable, and limited to what the collector can fix.
Post-capture failure messages remain necessary, but they are not a substitute
for useful pre-capture guidance.

## 6. Quality Belongs to the Selected Subject

### Principle

Image quality is judged in relation to the selected collectible, not the entire
photograph.

### Why

A cluttered shelf can still contain a clear, recognizable figure. Conversely, a
photograph that looks sharp overall may contain a blurred or tiny intended
subject. Whole-image quality is not the same as subject quality.

### Expected User Behavior

Collectors may use realistic shelf photographs without clearing the scene or
creating a studio background. They may be asked to retake a photograph when the
selected figure itself cannot be evaluated reliably.

### Product Implications

Background clutter alone must not make a recognition attempt invalid. Quality
feedback must describe the selected subject and should not imply that a normal
display shelf is inherently unsuitable.

## 7. Selection and Recognition Are Different Problems

### Principle

Shelfy first asks, “What is the user trying to recognize?” Only afterward does
it ask, “Which Catalog figure is this?”

### Why

Confusing intent with identity makes mistakes difficult to understand and
correct. A correct identity judgment about the wrong visible object is still a
failed user experience.

### Expected User Behavior

The collector establishes or confirms the subject, then evaluates the proposed
identity. Correcting the subject and correcting the identity are distinct
actions.

### Product Implications

Subject selection must remain independently correctable. Recognition must not
silently switch to another visible collectible merely because that object is
easier to identify.

## 8. Recognition Should Fail Gracefully

### Principle

When Shelfy is uncertain, it should say so and offer a safe next step. It must
not present an unreliable result with unwarranted confidence.

### Why

Collector trust is more valuable than the appearance of always having an
answer. A careful request for confirmation or another photograph is preferable
to confidently attaching the wrong identity to a cherished collection.

### Expected User Behavior

The collector may review plausible choices, confirm the intended result, adjust
the selected subject, or take another photograph.

### Product Implications

Uncertainty is a supported product outcome, not a system embarrassment. Shelfy
should use calm, actionable language and must never turn a weak suggestion into
a definitive claim.

## 9. Product Simplicity Is More Important Than Automation

### Principle

The goal is to make recognizing one intended collectible feel effortless, not
to maximize how much of a photograph Shelfy can process automatically.

### Why

More automation can create more ambiguity, more waiting, and more decisions for
the collector. A smaller experience with a clear purpose is often more useful
than an impressive experience that demands attention.

### Expected User Behavior

The collector focuses on one figure, receives a clear suggestion, and remains
in control of confirmation and correction.

### Product Implications

Product choices should reduce cognitive load and preserve a simple one-subject
flow. Automation is valuable only when it makes that flow easier without
weakening clarity, control, or trust.

## 10. Recognition Is Reversible

### Principle

Completing one recognition does not complete the photograph. Recognition is an
iterative interaction, and collectors should always be able to return to the
same photograph to recognize another intended collectible.

### Why

A photograph represents reusable context, not a completed task. Treating
recognition as reversible supports realistic collection photos without
encouraging unnecessary retakes or making one recognition close off other
intentions.

### Expected User Behavior

After identifying one collectible, the collector may immediately continue by
choosing another figure already visible in the same photograph. They may also
return to that photograph later when another collectible becomes relevant.

### Product Implications

Recognition must not consume, complete, or invalidate the photograph. Whenever
appropriate, Shelfy should preserve the collector's ability to continue
exploring the same image one intended collectible at a time.

## 11. User Intent Always Wins

### Principle

When the collector expresses an explicit intent, Shelfy must prefer that intent
over automatic inference.

### Why

Automatic assistance exists to reduce effort, not to replace the collector's
decision. Collectors should never feel that they are arguing with Shelfy about
what they meant to recognize.

### Expected User Behavior

The collector may accept a suggested subject, choose another visible
collectible, change an earlier choice, or retry recognition.

### Product Implications

Explicit user selection always overrides automatic selection. Shelfy may
continue to assist after that choice, but it must not silently substitute or
overrule the collector's intended subject.

## Enduring Product Standard

Shelfy Figure Recognition should always feel like a careful assistant helping a
collector answer one intentional question. It should work with real shelves,
respect uncertainty, preserve user control, and avoid turning a simple act of
identification into an attempt to understand everything in view.
