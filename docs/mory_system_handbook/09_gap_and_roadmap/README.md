# Gap And Roadmap

This roadmap is organized by product risk, not version number.

## Critical

| Gap | Impact | Recommended Fix |
| --- | --- | --- |
| Post-save AI status is weak | Users do not know whether Mory is still thinking, done, or failed. | Add product-level analysis status and ready/failed actions. |
| Voice refinement can overwrite edits | User trust risk during capture. | Add edit guard, diff, or confirmation before applying late cloud result. |
| Import provenance is too shallow | Multiple Journaling/share imports cannot be traced cleanly. | Add `importSessionID` and evidence provenance across artifacts/affect. |
| Subscription boundaries are not implemented | Paid launch would require risky migration. | Define server entitlement/quota contract before paywall work. |

## Important

| Gap | Impact | Recommended Fix |
| --- | --- | --- |
| SelfProfile has no clear product surface | User cannot inspect or edit what Mory knows about them. | Add My Profile status/edit/evidence screen. |
| Person profile evidence is not visible enough | Users cannot trust AI portraits. | Add field-level evidence viewer. |
| GraphDelta reject/reason/undo is incomplete | Corrections do not feel safe. | Productize proposal review workflow. |
| Journaling workout/event poster are not first-class cards | Imported suggestions feel incomplete. | Add activity/event context cards or better document cards. |
| Real-device background/APNs validation remains incomplete | Notification reliability unknown. | Maintain device validation log and acceptance checklist. |
| Background retry/quota/cancellation policy is still basic | The trigger surface is unified, but long-running failure policy is not productized. | Harden `BackgroundOperationOrchestrator` with explicit retry windows, cancellation, quotas, and product-readable status. |

## Product Clarity

| Gap | Impact | Recommended Fix |
| --- | --- | --- |
| Feature status scattered across docs | Product owner cannot tell what is real. | Keep this handbook updated on every change. |
| Debug and product state mixed | Users cannot see status without debug screens. | Notification and background state now have Settings/Debug pages; decide which summaries should become user-facing product status. |
| AI intervention points unclear | Users cannot predict when AI changes things. | Follow the AI Intervention Matrix for all future features. |

## Cleanup

| Gap | Impact | Recommended Fix |
| --- | --- | --- |
| Old analysis routes removed | Possible confusion in tests/debug. | Already hard-cut to unified Analysis; keep route tests only. |
| Some historical v7 flags remain in old implementation docs | Confusing status. | Mark deprecated or remove when no longer used. |
| Feature docs can drift | Recreates current problem. | Add a check in implementation workflow: feature docs updated with code. |

## Next Recommended Implementation Sequence

1. Add import session provenance.
2. Add voice refinement edit guard.
3. Add product Intelligence Status surface.
4. Add My Profile and profile evidence viewer.
5. Harden background retry/quota/cancellation after real-device BGTask/APNs validation.
6. Define entitlement/quota contract before any paywall UI.
