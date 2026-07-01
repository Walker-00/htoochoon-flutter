# Assignment vs Exam in Htoo Choon LMS

## Current Problem

The current implementation treats Assignments and Exams as essentially the same feature. Both use question-based assessments (Multiple Choice, True/False, Essay, Short Answer), causing students and instructors to perceive them as identical despite serving different educational purposes.

This creates several issues:

* Students cannot easily distinguish between homework and formal examinations.
* Instructors cannot configure assignment-specific workflows.
* The platform cannot evolve independently for assignments and exams.
* The user experience does not match expectations from modern LMS platforms.

---

# Understanding the Difference

## Assignment

Assignments are intended for learning, practice, projects, reports, and homework.

### Typical Characteristics

* Longer completion period (days or weeks)
* May require file uploads
* May require text submissions
* Usually manually graded
* Focused on learning and practice
* Can include instructor feedback and revisions

### Examples

* Research report
* Programming project
* Essay
* Presentation slides
* Homework exercises

---

## Exam

Exams are intended to measure student performance under controlled conditions.

### Typical Characteristics

* Fixed duration
* Start and end time
* Auto-submission
* Limited attempts
* Auto-grading for objective questions
* Higher academic importance

### Examples

* Chapter Quiz
* Midterm Examination
* Final Examination
* Placement Test

---

# Recommended Solution

## Assignment Module

Assignments should be redesigned around submissions rather than questions.

### Assignment Structure

```text
Assignment
├── Title
├── Description
├── Instructions
├── Due Date
├── Attachments
├── Submission Type
│   ├── File Upload
│   ├── Text Submission
│   └── Both
├── Max Score
└── Rubric
```

### Student Submission

```text
Assignment Submission
├── Uploaded Files
├── Written Response
├── Submitted At
├── Score
└── Instructor Feedback
```

### Grading Flow

Student
→ Submit Assignment
→ Instructor Reviews
→ Instructor Gives Score
→ Student Receives Feedback

---

## Exam Module

Exams should remain question-based.

### Exam Structure

```text
Exam
├── Title
├── Description
├── Duration
├── Start Time
├── End Time
├── Attempts
├── Passing Score
├── Randomization
└── Questions
```

### Supported Question Types

#### Auto-Graded

* Multiple Choice
* True / False

The system immediately calculates scores.

#### Manually Graded

* Short Answer
* Essay

The instructor reviews responses and awards marks.

### Grading Flow

Student
→ Take Exam
→ System Grades Objective Questions
→ Instructor Reviews Subjective Questions
→ Final Score Published

---

# UI Recommendations

Instead of:

```text
Assessments
├── Assignment A
├── Assignment B
├── Exam A
└── Exam B
```

Use:

```text
Assignments
├── Transportation Report
├── Homework 3
└── Programming Project

Exams
├── Chapter 1 Quiz
├── Midterm Exam
└── Final Exam
```

Students immediately understand the difference.

---

# Migration Plan

## Phase 1

Keep existing Exam functionality unchanged.

Current question types:

* Multiple Choice
* True / False
* Short Answer
* Essay

can remain under Exams.

---

## Phase 2

Redesign Assignments as submission-based activities.

Remove question requirements and support:

* File uploads
* Text submissions
* Instructor grading
* Feedback
* Rubrics

---

## Phase 3

Introduce a third category: Quiz

```text
Assessment Types

1. Assignment
   - Homework
   - Projects
   - Reports

2. Quiz
   - Short auto-graded tests
   - Practice assessments

3. Exam
   - Midterm
   - Final
   - High-stakes assessments
```

This model matches how most schools, universities, and online learning platforms organize assessments.

---

# Final Recommendation

For Htoo Choon LMS:

* Assignments should be submission-based.
* Exams should be question-based and timed.
* Quizzes should be lightweight auto-graded assessments.
* Do not use the same workflow for Assignments and Exams.
* Maintain separate UI sections and separate backend configurations for each type.

This approach will feel more natural to students, teachers, and school administrators while providing a cleaner foundation for future LMS features.

---

# Implementation Status (2026-06-16)

## Built now — simple working version

Assignments and Exams are now **separate workflows** (they already had separate
"Assignments" / "Exams" tabs; now they behave differently too):

- **Exam (TEST)** — unchanged: question-based, timed, proctored, auto-grades
  objective questions.
- **Assignment (ASSIGNMENT)** — submission-based:
  - Create form hides the question builder + duration; shows a due date and a
    "students write a response" note.
  - Student opens it → `SubmitAssignmentScreen`: a written-response text box,
    submitted once.
  - Backend (`submissions.service`): assignments skip question validation +
    auto-grading, store the response in the new `Submission.content` column, and
    are always `SUBMITTED` (pending manual grade, `score = null`).
  - Teacher grades it in `StudentSubmissionDetailScreen` (assignment branch):
    reads the response, enters one overall score (0–100) → `GRADED`.

### Deployment note
Backend needs `prisma migrate deploy` (migration
`20260616000000_assignment_submission_content` adds `Submission.content`) +
`prisma generate`, then a redeploy. The app needs a rebuild. No new env/packages.

## Deferred to later / PREMIUM (not built)

- **Rich "Google-Docs-style" document writer** for assignment responses
  (formatting, tables, embeds) — main web + cross-platform. Free tier keeps the
  plain text box; the rich editor is a premium upgrade.
- **File-upload submissions** (PDFs, images, docs) + rubric-based grading — the
  schema already has `SubmissionAttachment`; wiring + storage is the next step.
- **Quiz** as a distinct third type (Phase 3 above): lightweight auto-graded
  practice assessments separate from high-stakes exams.

