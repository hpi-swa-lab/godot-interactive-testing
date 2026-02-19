# Testy: Godot Interactive Testing

**Testy** is a Godot addon that allows developers to record game loops to create automated integration tests. Unlike standard unit testing tools, Testy focuses on the actual game loop, enabling recording, serialization of game states, playback and assertions.

## Quickstart
1. Clone the repository and move the `testy` folder into the `addons/` directory of your Godot project
2. Enable the plugin in the Godot settings **Project > Project Settings > Plugins**
3. To use it: Press **CTRL+R** while the game is running to start and stop a recording, or use the "Test Runner" panel in the editor at the bottom


## Abstract
Testy is a Godot addon designed to enable gameloop testing. It allows developers to record user interactions and replay them at. The tool combines input recording, game-state serialization, test playback, and assertions into a test workflow.

Automated testing in Godot is currently often complex and primarily focused on code-level unit tests. Testy addresses this gap by enabling automated testing of the game loop itself. This task is normally performed manually.

With Testy, users can record a gameplay session as a test: all mouse and keyboard inputs are captured, and the game state is serialized. After the recording, Testy computes the differences between the recorded states. Then the users can select which parameters should be used as test criteria. The tests can then be executed inside the running game or from the Godot editor. The original gamestate is restored, and the pre-recorded inputs are injected. After each execution, Testy verifies whether the defined criteria are fulfilled.

The motivation for Testy is to enable interactive gameplay tests while keeping the plugin architecture decoupled from the game code. It is designed to be usable without prior programming experience.


## How to Use Testy

The tool offers two main interaction modes: **In-Game Recording and Playback** and **Editor Playback**.

### 1. Recording/Running a Test (In-Game)

![Window for test criteria](readme-assets/window_test_criteria.png)

1. Run your game instance
2. Press **CTRL+R** to open the overview window
3. Press Start Recording
4. Perform the gameplay that you want to test
5. Press **CTRL+R** again to stop the test recording
6. The window at the top will open, showing the added, removed and changed objects during the recording
7. Select the parameters you want to add to your **Test Criteria** (Assertions)
8. Save the test with a test name
9. You can run the test within the current game instance by pressing **CTRL+R** again and selecting the test

### 2. Running Tests (Editor)

You can run existing tests directly from the Godot Editor

![Window test Runner](readme-assets/window_panel_test_runner.png)

1. Open the **Testy** panel at the bottom of the editor (see image at the top)
2. Click on the test that should be executed
3. View the results directly in the panel


## Games
This tool is currently used and tested with **Godot 4.5**, its functionality has been verified for:
- [ExtremeProGaming](https://github.com/hpi-swa-lab/ExtremeProGaming-Godot)
- [Babylonian Programming](https://github.com/hpi-swa-lab/babylonian-programming-godot/tree/eud25)

## Known Issues
**Input Interference:**
Currently, it is not possible to fully encapsulate keyboard input during test playback. If the test window is focused during playback, your manual keyboard interactions can interfere with the test (should not be a big problem, as this would be intentional interference).

**Input Recording Limitation:**
Testy records input by overriding `_input` and storing events together with the current tick. Limitation: If the game also overrides `_input` and consumes events (marks them as handled), there is no reliable way for the recorder to capture these events.

**Snapshot Limitation:**
Testy’s Snapshotter cannot reliably restore anonymous functions (lambdas) and async timers. It also cannot handle changes to the initial scene (added/removed nodes). Only changes in later scenes and code are supported.


## Architecture
![Architecture from the gofot-interactive-testing addon](readme-assets/godot-architecture.png)

## Game Architecture Overview

- **Game Instance:**
This is the actual running game instance, which does not need to follow specific conventions to be supported.
- **TestyPlugin:**
The entry point. Initializes the Autoload and the TestRunner.
- **Autoload:**
Manages and delegates functionality. Automatically added to the scene tree on game start.
- **Sandbox:**
Encapsulates the currently running scene to support full mouse isolation during playback. 
- **Snapshot:**
    - **Snapshotter:**
    Snapshots the current game state by traversing the root node and converting it into a storable format.
    - **SnapshotLoader:**
    Loads snapshot for test playback, using two-phase approach (restore serialized scene, remove all nodes that may have been spawned during initialization).
    - **Snapshot Comparator:**
    Compares two Snapshots to calculate the differnces (nodes added, removed, or parameters changed).
- **Input:**
    - **InputRecorder:**
    Listens to input events and saves it to a file along with the current game tick.
    - **InputPlayer:**
    Injects recorded inputs back into the Sandbox during playback.
- **TestManager:**
Manages test execution, file saving, and success status.
- **TestRunner:**
The interactive user interface within the Godot Editor for running multiple tests.


## Data architecture
Recorded tests are saved in the `tests` folder. Each test consists of the following files:

| Filename | Description |
| :--- | :--- |
| `test_case.tres` | Basic info: test name, creation date, seed, last successful execution. |
| `snapshot_a.tres` | Game state at the **start** of the recording. |
| `snapshot_b.tres` | Game state at the **end** of the recording. |
| `input_recording.tres` | Recorded input events (Event type, Ticks). |
| `assertions.testy` | The selected test criteria (what defines success). |
| `test_report.tres` | Output/Result from the last test run. |