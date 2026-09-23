# Screenshots · 界面截图

Regenerated from the running app, never touched up:

```sh
python3 scripts/screenshots.py            # iPhone 18 Pro Max, 1320 × 2868
python3 scripts/screenshots.py "iPhone 17"  # or any booted simulator
```

The script seeds a simulator with a kitchen worth photographing (`scripts/seed_state.swift`:
five people, two appliances, a planned week, a half-stocked fridge), runs
`FamilyKitchenScreenshots` against it, and pulls the pictures out of the result bundle.
A screenshot that no longer matches the app is worse than no screenshot, so none of
these is edited or kept by hand.

| File | What it shows |
|---|---|
| `01-today.png` | Today: the kitchen's own name, the day's breakfast and dinner, the five steps |
| `02-week.png` | The seven planned days, each meal confirmable or swappable |
| `03-recipes.png` | The catalogue — 56 dinners and 20 breakfasts, filterable and bilingual |
| `04-shopping.png` | The list built from the menu, with what is already at home subtracted |
| `05-listening.png` | Saying a change: the app listening, with the words appearing as they are heard |
| `06-understood.png` | What it understood, in both languages, waiting to be confirmed |
| `07-done.png` | Confirmed, with the change taken and an Undo beside it |
| `08-family-sharing-setup.png` | The family-sharing setup, as it looks before an iCloud account exists |

## About the voice pictures

`05`, `06` and `07` were produced with the transcript handed to the app rather than
spoken into a microphone. A simulator has no offline speech assets, so Apple's
recogniser cannot run there at all (see `VoiceListener.scriptedReadings`).

Everything in those pictures is the app's own behaviour on a real transcript: which of
the two languages was believed, the reading written back in English and Chinese, the
alternative offered underneath, and the fact that nothing has changed yet. What they do
**not** show is Apple's recogniser turning speech into that transcript — that has not
been photographed, because it needs a real iPhone.

## Using these on the App Store

1320 × 2868 is the 6.9-inch size Apple asks for, so these can be uploaded as they are.
They are, however, **a simulator showing seeded data**: a real listing should be shot on
a real device with a real family's week, and the recipe pictures in them are the app's
AI-generated illustrations rather than photographs of tested cooking — which the listing
has to say, as the README does.
