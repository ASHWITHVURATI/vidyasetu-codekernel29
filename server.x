"""
VidyaSetu - Adaptive Learning Backend Server
Built for Code Kernel '26 Hackathon (In collaboration with Canvas Classes)
Organized by X-Kernel, GRIET Hyderabad

Features:
- REST API for Student Adaptive Learning (Learn, Solve, Test)
- Bayesian Knowledge Tracing (BKT) Algorithm for Skill Mastery
- Misconception Diagnostic Engine
- Teacher Command Hub ('GuruSetu') Analytics & Quiet Gap Radar
- Serves Frontend Static Assets (index.html, styles.css, app.js)
"""

import os
import json
import math
from typing import Dict, List, Optional
from fastapi import FastAPI, HTTPException
from fastapi.staticfiles import StaticFiles
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel

app = FastAPI(
    title="VidyaSetu Adaptive Learning API",
    description="Adaptive Learning Backend for Indian Classes 6 to 10 (Code Kernel '26)",
    version="1.0.0"
)

# Enable CORS for cross-origin frontend requests
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# ---------------------------------------------------------------------------
# In-Memory Database / Data Store
# ---------------------------------------------------------------------------

# Class 8-B Sample Cohort (42 students simulated)
STUDENTS_COHORT = [
    {"id": 1, "name": "Priya Sharma", "roll": "8B-01", "status": "fast", "intOps": "mastered", "balance": "mastered", "wordProb": "mastered", "negCoeff": "mastered", "gapRisk": "Low", "masteryScore": 0.96},
    {"id": 2, "name": "Rahul Verma", "roll": "8B-02", "status": "standard", "intOps": "mastered", "balance": "mastered", "wordProb": "progress", "negCoeff": "progress", "gapRisk": "Low", "masteryScore": 0.78},
    {"id": 3, "name": "Aarav Patel", "roll": "8B-03", "status": "struggling", "intOps": "gap", "balance": "progress", "wordProb": "gap", "negCoeff": "gap", "gapRisk": "High (Class 7 Integers Gap)", "masteryScore": 0.42},
    {"id": 4, "name": "Sneha Reddy", "roll": "8B-04", "status": "standard", "intOps": "mastered", "balance": "mastered", "wordProb": "progress", "negCoeff": "mastered", "gapRisk": "Low", "masteryScore": 0.81},
    {"id": 5, "name": "Vikram Malhotra", "roll": "8B-05", "status": "fast", "intOps": "mastered", "balance": "mastered", "wordProb": "mastered", "negCoeff": "mastered", "gapRisk": "Low", "masteryScore": 0.94},
    {"id": 6, "name": "Ananya Iyer", "roll": "8B-06", "status": "struggling", "intOps": "gap", "balance": "gap", "wordProb": "gap", "negCoeff": "gap", "gapRisk": "High (Equations Foundation)", "masteryScore": 0.38},
    {"id": 7, "name": "Mohammed Zeeshan", "roll": "8B-07", "status": "standard", "intOps": "mastered", "balance": "progress", "wordProb": "progress", "negCoeff": "progress", "gapRisk": "Medium", "masteryScore": 0.69},
    {"id": 8, "name": "Divya Nambiar", "roll": "8B-08", "status": "standard", "intOps": "mastered", "balance": "mastered", "wordProb": "mastered", "negCoeff": "progress", "gapRisk": "Low", "masteryScore": 0.83}
]

# Adaptive Question Bank mapped to 3 Tiers
QUESTION_BANK = {
    1: {
        "level": "Foundational (Bridging)",
        "grade": 8,
        "prereqGrade": 6,
        "concept": "Basic Transposition",
        "equation": "x + 5 = 12",
        "prompt": "Solve for x. Think of undoing addition with subtraction.",
        "correctAnswer": "x = 7",
        "misconceptions": {
            "x = 17": "Added 5 instead of subtracting. Inverse of +5 is -5.",
            "x = 60": "Multiplied 12 × 5 instead of isolating x.",
            "x = 2.4": "Divided 12 by 5. Here 5 is added, not multiplied."
        },
        "hints": [
            "Hint 1: Look at + 5 on the left side. What is the opposite of adding 5?",
            "Hint 2: Subtract 5 from both sides: x + 5 - 5 = 12 - 5.",
            "Hint 3: 12 - 5 = 7. Therefore x = 7."
        ]
    },
    2: {
        "level": "Standard Grade Level (Class 8 NCERT)",
        "grade": 8,
        "concept": "Two-Step Linear Equations",
        "equation": "3x - 4 = 11",
        "prompt": "Solve for x. Remember: First undo subtraction, then undo multiplication.",
        "correctAnswer": "x = 5",
        "misconceptions": {
            "x = 2.33": "Subtracted 4 instead of adding 4 to 11. Inverse of -4 is +4!",
            "x = 7": "Transposed 4 correctly (15) but subtracted 3 instead of dividing by 3.",
            "x = 18": "Multiplied by 3 after addition instead of dividing."
        },
        "hints": [
            "Hint 1: First isolate the 3x term. What is the inverse of - 4?",
            "Hint 2: Add 4 to both sides: 3x = 11 + 4 = 15.",
            "Hint 3: Divide both sides by 3: x = 15 / 3 = 5."
        ]
    },
    3: {
        "level": "HOTS / Olympiad Challenge",
        "grade": 8,
        "concept": "Variables on Both Sides with Brackets",
        "equation": "5(x - 2) = 2(x + 7)",
        "prompt": "Solve for x. Challenge problem: Distribute first, then group variables on one side.",
        "correctAnswer": "x = 8",
        "misconceptions": {
            "x = 4": "Check distributive multiplication: 5 × (-2) and 2 × 7.",
            "x = 12": "Sign slip when transposing 2x or -10 across the equals sign.",
            "x = 6": "Arithmetic slip when adding 14 + 10."
        },
        "hints": [
            "Hint 1: Expand both brackets: 5x - 10 = 2x + 14.",
            "Hint 2: Subtract 2x from both sides: 3x - 10 = 14.",
            "Hint 3: Add 10 to both sides: 3x = 24 ⇒ x = 8."
        ]
    }
}

# ---------------------------------------------------------------------------
# Pydantic Request / Response Models
# ---------------------------------------------------------------------------

class DiagnosticAnswer(BaseModel):
    questionId: int
    concept: str
    isCorrect: bool

class DiagnosticSubmission(BaseModel):
    studentId: int
    answers: List[DiagnosticAnswer]

class AnswerAttempt(BaseModel):
    tier: int
    selectedAnswer: str

class DifferentiateRequest(BaseModel):
    classId: str = "8-B"

# ---------------------------------------------------------------------------
# Bayesian Knowledge Tracing (BKT) Implementation
# ---------------------------------------------------------------------------

def calculate_bkt(prior: float, is_correct: bool, p_transit: float = 0.15, p_slip: float = 0.10, p_guess: float = 0.20) -> float:
    """
    Standard Bayesian Knowledge Tracing calculation:
    - P(L_t|Correct) = [P(L_{t-1}) * (1 - P(Slip))] / [P(L_{t-1}) * (1 - P(Slip)) + (1 - P(L_{t-1})) * P(Guess)]
    - P(L_t|Incorrect) = [P(L_{t-1}) * P(Slip)] / [P(L_{t-1}) * P(Slip) + (1 - P(L_{t-1})) * (1 - P(Guess))]
    - P(L_t) = P(L_t|Evidence) + (1 - P(L_t|Evidence)) * P(Transit)
    """
    if is_correct:
        numerator = prior * (1.0 - p_slip)
        denominator = numerator + ((1.0 - prior) * p_guess)
    else:
        numerator = prior * p_slip
        denominator = numerator + ((1.0 - prior) * (1.0 - p_guess))

    p_posterior = numerator / denominator if denominator > 0 else prior
    p_mastery = p_posterior + ((1.0 - p_posterior) * p_transit)
    return round(min(max(p_mastery, 0.05), 0.99), 3)

# ---------------------------------------------------------------------------
# API Endpoints
# ---------------------------------------------------------------------------

@app.get("/api/health")
def health_check():
    return {
        "status": "healthy",
        "app": "VidyaSetu Adaptive Learning Server",
        "hackathon": "Code Kernel '26",
        "version": "1.0.0"
    }

@app.get("/api/cohort")
def get_cohort_summary():
    """Returns Class 8-B cohort data and Quiet Gap early detection radar"""
    quiet_gaps = [s for s in STUDENTS_COHORT if "High" in s["gapRisk"]]
    medium_gaps = [s for s in STUDENTS_COHORT if "Med" in s["gapRisk"]]
    mastered = [s for s in STUDENTS_COHORT if s["gapRisk"] == "Low"]

    return {
        "class": "8-B",
        "subject": "Mathematics",
        "totalStudents": len(STUDENTS_COHORT),
        "quietGapsCount": len(quiet_gaps),
        "students": STUDENTS_COHORT,
        "radarAlert": {
            "flagged": len(quiet_gaps) > 0,
            "message": f"{len(quiet_gaps)} students have latent Class 7 integer sign gaps before next week's chapter exam.",
            "flaggedStudents": [s["name"] for s in quiet_gaps]
        },
        "stats": {
            "mastered": len(mastered),
            "progressing": len(medium_gaps),
            "atRisk": len(quiet_gaps)
        }
    }

@app.post("/api/diagnostic/evaluate")
def evaluate_diagnostic(submission: DiagnosticSubmission):
    """Calculates updated Bayesian Knowledge Tracing mastery profile based on diagnostic pulse"""
    current_prior = 0.50
    concept_mastery = {}

    for ans in submission.answers:
        current_prior = calculate_bkt(current_prior, ans.isCorrect)
        concept_mastery[ans.concept] = current_prior

    # Determine recommended tier
    if current_prior >= 0.80:
        recommended_tier = 3
        action = "Accelerate to Tier 3 (HOTS & Olympiad)"
    elif current_prior >= 0.55:
        recommended_tier = 2
        action = "Standard NCERT Grade-Level Practice"
    else:
        recommended_tier = 1
        action = "Activate Class 6/7 Prerequisite Micro-Bridge"

    return {
        "studentId": submission.studentId,
        "updatedMasteryScore": current_prior,
        "conceptMastery": concept_mastery,
        "recommendedTier": recommended_tier,
        "systemAction": action
    }

@app.get("/api/solve/question/{tier}")
def get_adaptive_question(tier: int):
    """Fetches an adaptive question mapped to student tier (1, 2, or 3)"""
    if tier not in QUESTION_BANK:
        raise HTTPException(status_code=404, detail="Tier not found. Must be 1, 2, or 3.")
    
    q_data = QUESTION_BANK[tier]
    return {
        "tier": tier,
        "level": q_data["level"],
        "concept": q_data["concept"],
        "equation": q_data["equation"],
        "prompt": q_data["prompt"],
        "options": [q_data["correctAnswer"]] + list(q_data["misconceptions"].keys()),
        "hintsAvailable": len(q_data["hints"])
    }

@app.post("/api/solve/verify")
def verify_answer(attempt: AnswerAttempt):
    """Diagnoses misconceptions behind student answer choices"""
    tier = attempt.tier
    if tier not in QUESTION_BANK:
        raise HTTPException(status_code=404, detail="Invalid tier.")

    q = QUESTION_BANK[tier]
    ans = attempt.selectedAnswer.strip()

    if ans == q["correctAnswer"]:
        return {
            "correct": True,
            "message": "Outstanding work! Concept mastered.",
            "nextRecommendedTier": min(tier + 1, 3)
        }

    # Analyze root cause misconception
    reason = q["misconceptions"].get(ans, "Arithmetic calculation slip. Review step-by-step.")
    return {
        "correct": False,
        "misconceptionDiagnosed": True,
        "feedback": reason,
        "recommendedAction": "Step down to Foundational Tier 1" if tier > 1 else "Review Taraazu Balance scale"
    }

@app.post("/api/teacher/differentiate")
def auto_differentiate_class(req: DifferentiateRequest):
    """Auto-clusters classroom into 3 differentiated instructional tracks"""
    group_foundation = []
    group_standard = []
    group_olympiad = []

    for st in STUDENTS_COHORT:
        if st["masteryScore"] >= 0.85:
            group_olympiad.append(st["name"])
        elif st["masteryScore"] >= 0.60:
            group_standard.append(st["name"])
        else:
            group_foundation.append(st["name"])

    return {
        "class": req.classId,
        "totalClassSize": len(STUDENTS_COHORT),
        "groups": {
            "foundationalBridge": {
                "count": len(group_foundation),
                "students": group_foundation,
                "action": "10-min visual balance scale & Class 7 integer sign recap."
            },
            "coreNCERT": {
                "count": len(group_standard),
                "students": group_standard,
                "action": "Standard NCERT Chapter 2 problems with scaffolded hint ladders."
            },
            "olympiadHOTS": {
                "count": len(group_olympiad),
                "students": group_olympiad,
                "action": "Distributive bracket equations & multi-variable word problem challenges."
            }
        }
    }

@app.get("/api/parent-nudge/template")
def get_parent_nudge_templates():
    """Returns vernacular WhatsApp / SMS notifications for parent phones"""
    return {
        "english": "Namaste Parents! In Class 8-B this week, we are mastering Linear Equations. 6 students have a small gap in Class 7 integer signs. Please encourage your child to do today's 5-minute VidyaSetu offline/online worksheet. - Maths Teacher",
        "hindi": "नमस्ते अभिभावक! कक्षा 8-बी में इस सप्ताह हम रैखिक समीकरण सीख रहे हैं। कुछ बच्चों को कक्षा 7 के जोड़-घटाव में थोड़ी परेशानी आ रही है। कृपया शाम को 5 मिनट विद्यासेतु वर्कशीट में उनकी मदद करें। - गणित शिक्षिका",
        "telugu": "నమస్కారం తల్లిదండ్రులారా! ఈ వారం 8వ తరగతి-బి లో సరళ సమీకరణాలు నేర్చుకుంటున్నాము. మీ పిల్లలు ప్రతిరోజూ 5 నిమిషాల విద్యాసేతు అభ్యాస పత్రాన్ని పూర్తి చేసేలా ప్రోత్సహించండి. - గణిత ఉపాధ్యాయురాలు"
    }

# ---------------------------------------------------------------------------
# Serve Frontend Static Files
# ---------------------------------------------------------------------------
frontend_dir = os.path.dirname(os.path.abspath(__file__))

if os.path.exists(os.path.join(frontend_dir, "index.html")):
    app.mount("/", StaticFiles(directory=frontend_dir, html=True), name="static")

if __name__ == "__main__":
    import uvicorn
    print("\n" + "="*60)
    print("🚀 VidyaSetu Adaptive Learning Server Starting...")
    print("📍 Local Web App: http://localhost:8000")
    print("📚 Interactive Swagger API Docs: http://localhost:8000/docs")
    print("="*60 + "\n")
    uvicorn.run("server:app", host="0.0.0.0", port=8000, reload=True)
