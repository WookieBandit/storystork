// lib/story_structure_examples.dart - v1.0
// Contains general examples of well-structured stories with morals
// to be used as few-shot prompts for the AI.

const String exampleBoyWhoCriedWolfTitle = "The Boy Who Cried Wolf (Example of Honesty & Integrity)";
const String exampleBoyWhoCriedWolfSummary = """
A shepherd boy, bored while watching sheep, repeatedly tricks villagers by shouting "Wolf! Wolf!" When they rush to help, he laughs as there is no wolf. One day, a real wolf appears and attacks the sheep. The boy cries for help, but the villagers, assuming it's another false alarm, ignore him. The wolf harms the sheep, teaching the boy the consequence of his dishonesty.
""";
const String exampleBoyWhoCriedWolfMoral = "Liars will not be believed, even when they tell the truth.";

const String exampleTortoiseAndHareTitle = "The Tortoise and the Hare (Example of Resilience & Perseverance)";
const String exampleTortoiseAndHareSummary = """
A boastful hare ridicules a tortoise's slow pace. The tortoise challenges the hare to a race. Confident, the hare naps midway, underestimating the tortoise who plods along steadily. The hare wakes to find the tortoise near the finish line and sprints, but it's too late. The tortoise wins, demonstrating that consistent effort is crucial.
""";
const String exampleTortoiseAndHareMoral = "Perseverance and consistency can overcome natural advantages.";

// For simplicity in _generateContent, we can define a default structural example to use.
// This could be made more dynamic later (e.g., rotating examples or selecting based on criteria).
const String defaultStructuralExample = """
Here is an example of a well-structured short story that has a clear beginning, middle, and satisfying end, and also conveys a lesson:
--- EXAMPLE STORY START ---
Title: $exampleTortoiseAndHareTitle
Summary: $exampleTortoiseAndHareSummary
Moral/Lesson: $exampleTortoiseAndHareMoral
This example demonstrates good story structure and how a lesson can be integrated.
--- EXAMPLE STORY END ---

Now, keeping this example in mind for overall structure, completeness, and tone, please follow the specific request below.
""";