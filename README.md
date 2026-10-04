# Project 4 - Memory Game

Submitted by: **Ulises Alberto Cheong Borges**

**Memory Game** is a SwiftUI card-matching game where users memorize, flip, and match pairs of cards across multiple themes and difficulty levels. The app includes a memorization preview, animated card interactions, move and time tracking, persistent best scores, haptic feedback, accessibility support, and a polished responsive interface.

Time spent: 8 hours spent in total

## Required Features

The following **required** functionality is completed:

- [x] App loads to display a grid of cards initially placed face-down:
  - Upon launching the app, a grid of cards is visible.
  - Cards are face-down to indicate the start of the game.
  - Each card has exactly one matching partner.

- [x] Users can tap cards to toggle their display between the back and the face:
  - Tapping a face-down card flips it to reveal the front.
  - The first selected card remains visible while the user chooses a second card.
  - Selecting the same card twice does not count as a move.
  - Only two cards can be evaluated at a time.
  - If the cards do not match, both flip back face-down.

- [x] When two matching cards are found, they both disappear from view:
  - The app checks whether the two selected cards contain matching content.
  - Matching cards disappear with an animated transition.
  - Non-matching cards remain visible briefly before flipping back face-down.
  - Matched cards cannot be selected again.

- [x] User can reset the game and start a new game via a button:
  - A Reset Game button allows the user to start a fresh game.
  - Cards are reshuffled.
  - Matches, selections, moves, timer state, and other temporary game state are reset.
  - The selected theme and number of pairs are preserved.

## Optional Features

The following **optional** features are implemented:

- [x] User can select number of pairs to play with.
  - Supports **2, 4, 6, or 8 pairs**.
  - Changing the number of pairs creates a new shuffled board.

- [x] App allows for user to scroll to see content that may be out of view.
  - The interface uses a **ScrollView** for setup, gameplay, and completion content.

- [x] Customized visual appearance and animations.
  - Theme-aware colors, backgrounds, buttons, card backs, and card fronts.
  - Animated 3D card flips.
  - Animated matched-card disappearance.
  - Animated completion presentation.
  - Custom app icon.

## Additional Features

The following **additional** features are implemented:

- [x] Three selectable themes:
  - Fruit
  - Animals
  - Nature

- [x] Memorization preview before gameplay:
  - Cards begin face-down.
  - All cards briefly flip face-up simultaneously.
  - Cards remain visible for approximately 1.5 seconds.
  - All cards flip back face-down before gameplay begins.

- [x] Responsive card layout:
  - Supports 2, 4, 6, and 8-pair games.
  - The entire memorization preview remains visible at once in portrait mode.

- [x] Move counter:
  - A move is counted after selecting a second valid card.

- [x] Game timer:
  - Remains at 0:00 during setup and memorization preview.
  - Starts on the player's first valid card selection.
  - Stops when the game is completed.

- [x] Persistent best scores:
  - Best move count is saved separately for each game size.
  - Scores persist between app launches using `@AppStorage`.

- [x] Game completion screen:
  - Displays final move count and completion time.
  - Displays a New Best indicator when the player improves their score.
  - Allows the player to Play Again or return to setup.

- [x] Reset confirmation:
  - Prevents accidental loss of gameplay progress.

- [x] Change Setup flow:
  - Allows the user to return to theme and pair-count selection.

- [x] Haptic feedback:
  - Card flip feedback.
  - Match feedback.
  - Mismatch feedback.
  - Game completion feedback.

- [x] Accessibility support:
  - Meaningful accessibility labels for cards and controls.
  - Matched-card placeholders are hidden from accessibility.
  - Decorative UI elements are excluded from accessibility navigation.

- [x] Custom app icon.

## Video Walkthrough

Here's a walkthrough of implemented user stories:

[Memory Game Video Walkthrough](https://youtube.com/shorts/ejgknZyALAg?feature=share)

## Notes

One of the main challenges was coordinating card-selection state with asynchronous animations. The app needed to prevent a third card from being selected while a mismatched pair was still visible and also safely cancel pending animations whenever the game was reset.

Another challenge was implementing the memorization preview while ensuring that all cards remain visible at the same time for every supported game size. The card grid dynamically adjusts its rows, columns, spacing, and card dimensions so that games with up to 16 cards fit within the available portrait layout.

The timer, reset behavior, persistent best scores, theme changes, and preview sequence also required careful state management so that starting a new game completely resets temporary gameplay state without affecting saved scores or the selected configuration.

## License

    Copyright 2026 Ulises Alberto Cheong Borges

    Licensed under the Apache License, Version 2.0 (the "License");
    you may not use this file except in compliance with the License.
    You may obtain a copy of the License at

        http://www.apache.org/licenses/LICENSE-2.0

    Unless required by applicable law or agreed to in writing, software
    distributed under the License is distributed on an "AS IS" BASIS,
    WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
    See the License for the specific language governing permissions and
    limitations under the License.
