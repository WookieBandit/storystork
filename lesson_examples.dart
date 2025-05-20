// lib/lesson_examples.dart - v1.0
// Contains example story summaries and morals for few-shot prompting.

const Map<String, Map<String, String>> lessonExamples = {
  'Friendship & Loyalty': { // Corresponds to "The Lion and the Mouse"
    'title': "The Lion and the Mouse (Example of Friendship & Loyalty)",
    'summary': """
A lion is awakened by a mouse running across his face. The lion catches the mouse, intending to kill it, but the mouse pleads for its life, promising to repay the kindness. Amused, the lion lets it go. Later, the lion is caught in a hunter's net. The mouse hears his roars, remembers its promise, and gnaws through the ropes, freeing the lion. The lion realizes even the smallest creature can be a great friend.
""",
    'moral': "Acts of kindness, no matter how small, can be repaid in unexpected ways; even the weak can help the strong."
  },
  'Kindness & Empathy': { // Corresponds to "The Elves and the Shoemaker" or "The Little Match-Girl"
                             // Let's use "The Elves and the Shoemaker" as it's more about proactive kindness being rewarded.
    'title': "The Elves and the Shoemaker (Example of Kindness & Empathy)",
    'summary': """
A kind but poor shoemaker has only enough leather for one last pair of shoes, leaving it cut out overnight. In the morning, the shoes are perfectly made. This miracle repeats, and he becomes successful. He and his wife stay up to discover small, naked elves making the shoes. Filled with gratitude, they make tiny clothes and shoes for the elves. The delighted elves dress and dance away, never returning, but the shoemaker continues to prosper.
""",
    'moral': "Kindness and hard work are often rewarded in unexpected ways; gratitude inspires further generosity."
  },
  'Honesty & Integrity': { // Corresponds to "The Boy Who Cried Wolf" or "The Emperor's New Clothes"
                           // Let's use "The Boy Who Cried Wolf"
    'title': "The Boy Who Cried Wolf (Example of Honesty & Integrity)",
    'summary': """
A shepherd boy, bored while watching sheep, repeatedly tricks villagers by shouting "Wolf! Wolf!" When they rush to help, he laughs as there is no wolf. One day, a real wolf appears and attacks the sheep. The boy cries for help, but the villagers, assuming it's another false alarm, ignore him. The wolf harms the sheep, teaching the boy the consequence of his dishonesty.
""",
    'moral': "Liars will not be believed, even when they tell the truth."
  },
  'Resilience & Perseverance': { // Corresponds to "The Tortoise and the Hare" or "The Ugly Duckling"
                                  // Let's use "The Tortoise and the Hare"
    'title': "The Tortoise and the Hare (Example of Resilience & Perseverance)",
    'summary': """
A boastful hare ridicules a tortoise's slow pace. The tortoise challenges the hare to a race. Confident, the hare naps midway, underestimating the tortoise who plods along steadily. The hare wakes to find the tortoise near the finish line and sprints, but it's too late. The tortoise wins, demonstrating that consistent effort is crucial.
""",
    'moral': "Perseverance and consistency can overcome natural advantages."
  },
  'Social Behavior & Respect': { // Corresponds to "Little Red-Cap" or "The Fox and the Grapes"
                                    // Let's use "The Fox and the Grapes" as a slightly different take on social behavior (rationalization)
    'title': "The Fox and the Grapes (Example of Perspective on Attainment)",
    'summary': """
A hungry fox spots ripe grapes hanging high on a vine. After many failed attempts to reach them, the tired and frustrated fox gives up. Walking away, it mutters that the grapes were probably sour anyway, belittling what it could not obtain.
""",
    'moral': "It is easy to despise what one cannot attain." 
    // Note: Little Red-Cap is also good for "dangers of disobeying advice / talking to strangers"
  },
  // We can add more examples for the lessons if needed, or use these as primary.
  // The _availableLessons list in main.dart currently has these 5 categories.
  // If you want to use more of your 10 stories, we'd need to map them to these lesson categories
  // or expand the lesson categories in main.dart.
  // For now, I've picked one representative summary for each of your 5 lesson categories.
};

// You can also add your poem examples here if we decide to use them for 'Poem' content type
// const Map<String, Map<String, String>> poemLessonExamples = { ... };