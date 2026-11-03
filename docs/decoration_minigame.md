# Kitchen decoration minigame

The kitchen scene includes `DecorationStation` to the right of the existing kitchen, at `(8.5, 0, -3.1)`.

## Interaction

- The box supplies the 13 pennants in `HAPPY BIRTHDAY`, shuffled without replacement. Any banner can use any empty banner marker.
- Only banner markers show crossed tape, with stable variations in strip size, angle, offset, and shade. There are no ghost decorations, instructions, counts, or reticles. Looking at the box fades in only “Decoration Box”.
- Held pennants smoothly approach nearby empty markers, floating 0.06 units in front at 1.08 scale. A fresh click attaches at 1.0 scale. Empty-handed clicks take attached banners down for rearrangement, revealing their tape again.
- Banner and balloon draws have no required order. The balloon weight beside the box supplies ten deflated balloons in random order: variants 1–5, exactly two each. Actual artwork colors are 1/2/5 pink (six total), 3/4 green (four total), and remain consistent through inflation and attachment.
- Aim a deflated balloon at the pump to lerp it to the nozzle, turning it upside down by 180 degrees. Click to inflate it on the pump. Inflation takes 0.45 seconds and changes to its matching inflated `hand` image. Click the pump again after inflation finishes to retrieve it.
- An inflated balloon smoothly follows the aimed position anywhere on the front of the decoration wall. Click to attach it at that exact point. Only attachment changes the image to its corresponding ribbon/string version. Inflating, inflated, and attached balloons always face the active camera. Their balloon/ribbon/string sprites use foreground render priority with depth testing disabled so pennants and cords cannot cover them. There are no balloon markers or tape, and deflated balloons cannot be attached.
- The occupied pump blocks further supply draws until its balloon is retrieved, keeping the player's hands available. Held decorations also block additional draws. Empty supplies cannot create extras.
- Looking at the balloon weight with empty hands lifts and bobs its bag using the same hover motion as the pepper shaker. Looking away, holding an item, or exhausting the balloon supply returns it to rest. Its collider stays still.
- **F** focuses/leaves the wall; **Esc** also leaves. Normal movement and placement work without focusing the wall. Focusing extends interaction reach to cover its edges.

## Editing

Open `prefabs/decoration_station.tscn`, or enable editable children on the kitchen's station instance.

- `DecorationWall/BannerSlots`: editable `Marker3D` nodes; positions and rotations determine final pennant poses. Their item IDs build the finite banner inventory.
- `BalloonWeight`: uses the existing weight sprite and a shuffled finite variant bag. `box_path` links it to the same decoration wall, without gating balloon draws on banner progress; its sibling `BalloonPump` provides occupancy gating.
- `BalloonPump/Nozzle`: editable `Marker3D` controlling the hover/inflation pose. The pump currently uses a mesh placeholder because there is no pump artwork in the project.
- `BoxTable` supports the box, weight, and pump. `PlayerLockPoint` controls wall focus position.
- `PartyBalloon` uses the supplied deflated, hand, and string PNGs. The first hand asset is named `ballon_1_hand.png` (one o); this is handled explicitly. Full-size string art retains the inflated balloon body's size and top position.
- `DecorationWall.balloon_target_count` defaults to 10. `placed_count` includes all attached banners and balloons. `decoration_placed`, `decoration_removed`, and `completed` support later minigame stages. Completion requires 13 banners and 10 balloons; removing/replacing a banner updates the count and can re-emit completion.

## Verification

Run `res://tests/decoration_flow_test.tscn` or:

```sh
godot --headless --path . --fixed-fps 60 --quit-after 1200 res://tests/decoration_flow_test.tscn
```

The integration test loads the kitchen and exercises the player's ray and interaction dispatcher for balloon-before-banner draws, mixed ordering, free letter placement, smooth hover/return, varied banner-only tape, click-only attachment, empty-handed removal/repositioning, blocked pickup, upside-down nozzle lerp, color preservation for all five variants, camera-facing and foreground rendering settings, inflation timing, retrieval, all ten variant/color counts, finite inventory, occupied-pump protection, arbitrary wall placement, texture changes, and completion. It also verifies banner snapping after moving/rotating the station.
