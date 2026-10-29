/**
 * VidyaSetu - Adaptive Learning Backend Server (Node.js / Express)
 * Built for Code Kernel '26 Hackathon (In collaboration with Canvas Classes)
 * Organized by X-Kernel, GRIET Hyderabad
 */

const express = require('express');
const cors = require('cors');
const path = require('path');

const app = express();
const PORT = process.env.PORT || 8000;

app.use(cors());
app.use(express.json());

// Cohort Data (42 students simulated)
const STUDENTS_COHORT = [
  { id: 1, name: "Priya Sharma", roll: "8B-01", status: "fast", intOps: "mastered", balance: "mastered", wordProb: "mastered", negCoeff: "mastered", gapRisk: "Low", masteryScore: 0.96 },
  { id: 2, name: "Rahul Verma", roll: "8B-02", status: "standard", intOps: "mastered", balance: "mastered", wordProb: "progress", negCoeff: "progress", gapRisk: "Low", masteryScore: 0.78 },
  { id: 3, name: "Aarav Patel", roll: "8B-03", status: "struggling", intOps: "gap", balance: "progress", wordProb: "gap", negCoeff: "gap", gapRisk: "High (Class 7 Integers Gap)", masteryScore: 0.42 },
  { id: 4, name: "Sneha Reddy", roll: "8B-04", status: "standard", intOps: "mastered", balance: "mastered", wordProb: "progress", negCoeff: "mastered", gapRisk: "Low", masteryScore: 0.81 },
  { id: 5, name: "Vikram Malhotra", roll: "8B-05", status: "fast", intOps: "mastered", balance: "mastered", wordProb: "mastered", negCoeff: "mastered", gapRisk: "Low", masteryScore: 0.94 },
  { id: 6, name: "Ananya Iyer", roll: "8B-06", status: "struggling", intOps: "gap", balance: "gap", wordProb: "gap", negCoeff: "gap", gapRisk: "High (Equations Foundation)", masteryScore: 0.38 },
  { id: 7, name: "Mohammed Zeeshan", roll: "8B-07", status: "standard", intOps: "mastered", balance: "progress", wordProb: "progress", negCoeff: "progress", gapRisk: "Medium", masteryScore: 0.69 },
  { id: 8, name: "Divya Nambiar", roll: "8B-08", status: "standard", intOps: "mastered", balance: "mastered", wordProb: "mastered", negCoeff: "progress", gapRisk: "Low", masteryScore: 0.83 }
];

// Adaptive Question Bank
const QUESTION_BANK = {
  1: {
    level: "Foundational (Bridging)",
    equation: "x + 5 = 12",
    prompt: "Solve for x. Think of undoing addition with subtraction.",
    correctAnswer: "x = 7",
    misconceptions: {
      "x = 17": "Added 5 instead of subtracting. Inverse of +5 is -5.",
      "x = 60": "Multiplied 12 × 5. To isolate x, subtract 5 from 12.",
      "x = 2.4": "Divided 12 by 5. Here 5 is added to x, not multiplied."
    }
  },
  2: {
    level: "Standard Grade Level (Class 8 NCERT)",
    equation: "3x - 4 = 11",
    prompt: "Solve for x. Remember: First undo subtraction, then undo multiplication.",
    correctAnswer: "x = 5",
    misconceptions: {
      "x = 2.33": "Subtracted 4 instead of adding 4 to 11. Inverse of -4 is +4!",
      "x = 7": "Added 4 correctly but subtracted 3 instead of dividing.",
      "x = 18": "Multiplied 3 after addition instead of dividing."
    }
  },
  3: {
    level: "HOTS / Olympiad Challenge",
    equation: "5(x - 2) = 2(x + 7)",
    prompt: "Solve for x. Challenge: Distribute first, then group variables on one side.",
    correctAnswer: "x = 8",
    misconceptions: {
      "x = 4": "Check distributive bracket multiplication: 5 × (-2) and 2 × 7.",
      "x = 12": "Sign slip when transposing 2x or -10 across equals sign.",
      "x = 6": "Arithmetic slip when adding 14 + 10."
    }
  }
};

// Bayesian Knowledge Tracing (BKT)
function calculateBKT(prior, isCorrect, pTransit = 0.15, pSlip = 0.10, pGuess = 0.20) {
  let numerator, denominator;
  if (isCorrect) {
    numerator = prior * (1.0 - pSlip);
    denominator = numerator + (1.0 - prior) * pGuess;
  } else {
    numerator = prior * pSlip;
    denominator = numerator + (1.0 - prior) * (1.0 - pGuess);
  }
  const pPosterior = denominator > 0 ? numerator / denominator : prior;
  const pMastery = pPosterior + (1.0 - pPosterior) * pTransit;
  return Number(Math.min(Math.max(pMastery, 0.05), 0.99).toFixed(3));
}

// REST Endpoints
app.get('/api/health', (req, res) => {
  res.json({ status: "healthy", server: "Express.js", app: "VidyaSetu Adaptive Engine", version: "1.0.0" });
});

app.get('/api/cohort', (req, res) => {
  const quietGaps = STUDENTS_COHORT.filter(s => s.gapRisk.includes("High"));
  res.json({
    class: "8-B",
    subject: "Mathematics",
    totalStudents: STUDENTS_COHORT.length,
    quietGapsCount: quietGaps.length,
    students: STUDENTS_COHORT,
    radarAlert: {
      flagged: quietGaps.length > 0,
      message: `${quietGaps.length} students have latent Class 7 integer sign gaps before next week's chapter exam.`,
      flaggedStudents: quietGaps.map(s => s.name)
    }
  });
});

app.post('/api/diagnostic/evaluate', (req, res) => {
  const { answers } = req.body;
  let prior = 0.50;
  const conceptMastery = {};

  if (Array.isArray(answers)) {
    answers.forEach(ans => {
      prior = calculateBKT(prior, ans.isCorrect);
      conceptMastery[ans.concept] = prior;
    });
  }

  const recommendedTier = prior >= 0.80 ? 3 : (prior >= 0.55 ? 2 : 1);
  res.json({
    updatedMasteryScore: prior,
    conceptMastery,
    recommendedTier,
    systemAction: recommendedTier === 3 ? "Accelerate to Tier 3 (Olympiad)" : (recommendedTier === 2 ? "Standard NCERT Pace" : "Activate Class 6/7 Prerequisite Micro-Bridge")
  });
});

app.get('/api/solve/question/:tier', (req, res) => {
  const tier = parseInt(req.params.tier);
  const q = QUESTION_BANK[tier];
  if (!q) return res.status(404).json({ error: "Tier not found" });

  res.json({
    tier,
    level: q.level,
    equation: q.equation,
    prompt: q.prompt,
    options: [q.correctAnswer, ...Object.keys(q.misconceptions)]
  });
});

app.post('/api/solve/verify', (req, res) => {
  const { tier, selectedAnswer } = req.body;
  const q = QUESTION_BANK[tier];
  if (!q) return res.status(400).json({ error: "Invalid tier" });

  if (selectedAnswer.trim() === q.correctAnswer) {
    return res.json({ correct: true, message: "Outstanding! Concept mastered.", nextTier: Math.min(tier + 1, 3) });
  }

  const feedback = q.misconceptions[selectedAnswer.trim()] || "Check arithmetic calculations.";
  res.json({ correct: false, feedback, recommendedAction: tier > 1 ? "Step down to Foundational Tier 1" : "Review Taraazu Balance scale" });
});

app.post('/api/teacher/differentiate', (req, res) => {
  const groupFoundation = STUDENTS_COHORT.filter(s => s.masteryScore < 0.60).map(s => s.name);
  const groupStandard = STUDENTS_COHORT.filter(s => s.masteryScore >= 0.60 && s.masteryScore < 0.85).map(s => s.name);
  const groupOlympiad = STUDENTS_COHORT.filter(s => s.masteryScore >= 0.85).map(s => s.name);

  res.json({
    class: "8-B",
    groups: {
      foundationalBridge: { count: groupFoundation.length, students: groupFoundation },
      coreNCERT: { count: groupStandard.length, students: groupStandard },
      olympiadHOTS: { count: groupOlympiad.length, students: groupOlympiad }
    }
  });
});

// Serve frontend static files
app.use(express.static(path.join(__dirname, '.')));

app.listen(PORT, () => {
  console.log(`\n🚀 VidyaSetu Express Backend running on http://localhost:${PORT}`);
  console.log(`📁 Serving frontend from ${__dirname}\n`);
});
