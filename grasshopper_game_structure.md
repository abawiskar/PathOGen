# Grasshopper game: group labels and structure

This guide records the current canvas convention and the steps for adding another multiple choice question.

## Canvas structure

Each large **white** group (`A01`–`A05`) is one method for creating the same result. Inside it, smaller **untitled white** groups divide the working definition into stages. A **red** group marks the wired component that is the correct answer for a stage.

The quiz components sit beside the method. Their matching question ID links them to the red group; they do not need to be members of the large white group.

| Group | Label pattern | Contents | Color (A, R, G, B) |
| --- | --- | --- | --- |
| Method | `A01` … `A05` | Working definition and stage groups | `225, 255, 255, 255` |
| Stage | No label | Components used in one stage | `225, 255, 255, 255` |
| Wired answer | `A##_Q##` | Original correct component in the working definition | `225, 255, 0, 0` |
| Quiz answer | `A##_Q##_Correct` | Locked native copy of that correct component | `225, 161, 205, 68` |
| Wrong choices | `A##_Q##_Choices` | Native components that fail to perform that step | `180, 0, 135, 220` |

For example, `A03_Q01` is the wired red answer for the first question in method `A03`. Its green quiz copy is `A03_Q01_Correct`, placed above the blue `A03_Q01_Choices` group.

## Add a question

1. Build the stage in the large white method group. Keep its working components and wires in an untitled white stage group.
2. Group the one correct working component in red. Name that group `A##_Q##`, using a two-digit question number in stage order.
3. Create a **native Grasshopper** copy of that component for the quiz. Leave it unwired, lock it, group it in green, and name the group `A##_Q##_Correct`.
4. Place the green group just above the matching blue choices group. On the current canvas its left edge is about 5 canvas units to the right of the blue group's left edge, and its top is about 112 units above the blue group's top. Adjust spacing if a component is taller.
5. Add twelve distinct, native Grasshopper components that are **wrong for this exact step** to a blue `A##_Q##_Choices` group. They should be plausible multiple choice distractors, but they must not be valid substitutes for the red component with the step's intended inputs and output. Leave them unwired and locked so they do not create previews or input warnings.
6. Check the labels, colors, component count, spacing, and native component source. The quiz groups must not overlap other answer banks or the working definitions. Keep the original method wires intact.

The current quiz components came from Rhino 8's bundled Grasshopper assemblies: `Grasshopper.dll`, `MathComponents.gha`, `CurveComponents.gha`, `SurfaceComponents.gha`, `VectorComponents.gha`, and `XformComponents.gha`.

## Current question IDs

| Method | Red answer components, in question order |
| --- | --- |
| `A01` | `Q01` Construct Point; `Q02` Polygon |
| `A02` | `Q01` Construct Point; `Q02` Line SDL; `Q03` Rotate; `Q04` End Points; `Q05` Fillet |
| `A03` | `Q01` Construct Point; `Q02` Move; `Q03` Series; `Q04` Rotate; `Q05` Discontinuity |
| `A04` | `Q01` Construct Point; `Q02` Divide Curve; `Q03` Shift List; `Q04` PolyLine; `Q05` Flatten Tree |
| `A05` | `Q01` Construct Point; `Q02` Divide Curve; `Q03` Trim with Region; `Q04` Arc SED; `Q05` Shift List; `Q06` Merge |

There are **23 questions**. At the time this guide was written, `A03_Q01_Choices` contains **11** components; every other choices group contains **12**. The existing green correct group for `A03_Q01` was used as the color and layout reference.

## Difficulty names

These are the game's five difficulty names, from easiest to hardest. They are separate from the `A01`–`A05` method IDs:

1. Hopper Hatchling
2. Shape Scout
3. Pattern Pouncer
4. Geometry Wizard
5. Grasshopper Legend
