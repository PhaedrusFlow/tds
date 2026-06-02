/* ── Types ─────────────────────────────────────────────────────── */

/**
 * @typedef {Object} QuizCatalogItem
 * @property {string} id
 * @property {string} title
 * @property {string} description
 * @property {string} file
 * @property {number | null} questionCount
 */

/**
 * @typedef {Object} Question
 * @property {number | string} [id]
 * @property {string} question
 * @property {string[]} choices
 * @property {string} answer
 * @property {string} [explanation]
 */

/**
 * @typedef {Object} QuizFile
 * @property {string} [id]
 * @property {string} [title]
 * @property {string} [description]
 * @property {Question[]} questions
 */

/**
 * @typedef {Object} QuizResult
 * @property {Question} question
 * @property {string | null} selected
 * @property {boolean} correct
 */

/**
 * @typedef {Object} AppState
 * @property {QuizCatalogItem | null} currentQuiz
 * @property {Question[]} questions
 * @property {number} currentIndex
 * @property {(string | null)[]} answers
 * @property {QuizResult[]} results
 * @property {boolean} shuffleQ
 * @property {boolean} shuffleC
 * @property {boolean} showExplanations
 */

/* ── State ─────────────────────────────────────────────────────── */

/** @type {QuizCatalogItem[]} */
let quizCatalog = [];

/** @type {AppState} */
let state = {
    currentQuiz: null,
    questions: [],
    currentIndex: 0,
    answers: [],
    results: [],
    shuffleQ: true,
    shuffleC: false,
    showExplanations: true,
};

/* ── DOM helpers ───────────────────────────────────────────────── */

/**
 * @template {Element} T
 * @param {string} selector
 * @returns {T | null}
 */
function $(selector) {
    return /** @type {T | null} */ (document.querySelector(selector));
}

/* ── Element refs ──────────────────────────────────────────────── */

const els = {
    quizSelect: /** @type {HTMLSelectElement | null} */ ($("#quiz-select")),
    startBtn: /** @type {HTMLButtonElement | null} */ ($("#start-btn")),
    restartBtn: /** @type {HTMLButtonElement | null} */ ($("#restart-btn")),
    quizMeta: /** @type {HTMLDivElement | null} */ ($("#quiz-meta")),

    shuffleQuestions:
        /** @type {HTMLInputElement | null} */ ($("#shuffle-questions")),
    shuffleChoices:
        /** @type {HTMLInputElement | null} */ ($("#shuffle-choices")),
    showExplanations:
        /** @type {HTMLInputElement | null} */ ($("#show-explanations")),

    welcomeCard: /** @type {HTMLElement | null} */ ($("#welcome-card")),
    quizCard: /** @type {HTMLElement | null} */ ($("#quiz-card")),
    resultsCard: /** @type {HTMLElement | null} */ ($("#results-card")),

    quizTitle: /** @type {HTMLElement | null} */ ($("#quiz-title")),
    questionCounter: /** @type {HTMLElement | null} */ ($("#question-counter")),
    answeredCounter: /** @type {HTMLElement | null} */ ($("#answered-counter")),
    scorePreview: /** @type {HTMLElement | null} */ ($("#score-preview")),
    progressFill: /** @type {HTMLElement | null} */ ($("#progress-fill")),
    questionText: /** @type {HTMLElement | null} */ ($("#question-text")),
    choicesForm: /** @type {HTMLFormElement | null} */ ($("#choices-form")),

    prevBtn: /** @type {HTMLButtonElement | null} */ ($("#prev-btn")),
    nextBtn: /** @type {HTMLButtonElement | null} */ ($("#next-btn")),
    submitBtn: /** @type {HTMLButtonElement | null} */ ($("#submit-btn")),

    resultsScore: /** @type {HTMLElement | null} */ ($("#results-score")),
    resultsSummary: /** @type {HTMLElement | null} */ ($("#results-summary")),
    reviewList: /** @type {HTMLDivElement | null} */ ($("#review-list")),

    themeToggle:
        /** @type {HTMLButtonElement | null} */ ($("[data-theme-toggle]")),
};

/* ── Theme ─────────────────────────────────────────────────────── */

/**
 * @param {HTMLButtonElement} btn
 * @param {string} theme
 */
function updateThemeIcon(btn, theme) {
    btn.setAttribute(
        "aria-label",
        `Switch to ${theme === "dark" ? "light" : "dark"} mode`,
    );

    btn.innerHTML = theme === "dark"
        ? '<svg width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><circle cx="12" cy="12" r="5"></circle><path d="M12 1v2M12 21v2M4.22 4.22l1.42 1.42M18.36 18.36l1.42 1.42M1 12h2M21 12h2M4.22 19.78l1.42-1.42M18.36 5.64l1.42-1.42"></path></svg>'
        : '<svg width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><path d="M21 12.79A9 9 0 1 1 11.21 3 7 7 0 0 0 21 12.79z"></path></svg>';
}

function initTheme() {
    const btn = els.themeToggle;
    const root = document.documentElement;
    const prefersDark =
        window.matchMedia("(prefers-color-scheme: dark)").matches;
    let theme = root.getAttribute("data-theme") ||
        (prefersDark ? "dark" : "light");

    root.setAttribute("data-theme", theme);

    if (btn) {
        updateThemeIcon(btn, theme);
        btn.addEventListener("click", () => {
            theme = theme === "dark" ? "light" : "dark";
            root.setAttribute("data-theme", theme);
            updateThemeIcon(btn, theme);
        });
    }
}

/* ── Utility ───────────────────────────────────────────────────── */

/**
 * @template T
 * @param {T[]} arr
 * @returns {T[]}
 */
function shuffle(arr) {
    for (let i = arr.length - 1; i > 0; i -= 1) {
        const j = Math.floor(Math.random() * (i + 1));
        const temp = arr[i];
        arr[i] = arr[j];
        arr[j] = temp;
    }

    return arr;
}

/**
 * @param {string} str
 * @returns {string}
 */
function escHtml(str) {
    return String(str)
        .replace(/&/g, "&amp;")
        .replace(/</g, "&lt;")
        .replace(/>/g, "&gt;")
        .replace(/"/g, "&quot;");
}

/**
 * @param {boolean} showQuiz
 * @param {boolean} showResults
 */
function setView(showQuiz, showResults) {
    els.welcomeCard?.classList.toggle("hidden", showQuiz || showResults);
    els.quizCard?.classList.toggle("hidden", !showQuiz);
    els.resultsCard?.classList.toggle("hidden", !showResults);
}

/* ── Catalog ───────────────────────────────────────────────────── */

async function loadQuizCatalog() {
    const response = await fetch(`./data/manifest.json?v=${Date.now()}`);

    if (!response.ok) {
        throw new Error(`Unable to load manifest.json (${response.status})`);
    }

    /** @type {unknown} */
    const data = await response.json();

    if (!Array.isArray(data)) {
        throw new Error("manifest.json is not an array");
    }

    quizCatalog = /** @type {QuizCatalogItem[]} */ (data);
}

function renderQuizSelect() {
    const select = els.quizSelect;
    if (!select) return;

    select.innerHTML = "";

    quizCatalog.forEach((quiz) => {
        const option = document.createElement("option");
        option.value = quiz.id;
        option.textContent = quiz.title;
        select.appendChild(option);
    });
}

function updateQuizMeta() {
    const select = els.quizSelect;
    const meta = els.quizMeta;

    if (!select || !meta) return;

    const quiz = quizCatalog.find((item) => item.id === select.value);

    if (!quiz) {
        meta.innerHTML = "<p>Pick a test to begin.</p>";
        return;
    }

    const count = quiz.questionCount == null ? "?" : String(quiz.questionCount);

    meta.innerHTML = `
    <p><strong>${escHtml(quiz.title)}</strong></p>
    <p>${
        escHtml(quiz.description || "Quiz loaded from JSON question bank.")
    }</p>
    <p>${count} question${count === "1" ? "" : "s"}</p>
  `;
}

/* ── Quiz loading ──────────────────────────────────────────────── */

/**
 * @param {QuizCatalogItem} quiz
 */
async function loadQuiz(quiz) {
    const response = await fetch(`./${quiz.file}?v=${Date.now()}`);

    if (!response.ok) {
        throw new Error(
            `Unable to load quiz file: ${quiz.file} (${response.status})`,
        );
    }

    /** @type {QuizFile} */
    const data = await response.json();

    const questions = Array.isArray(data.questions)
        ? data.questions.slice()
        : [];

    state.currentQuiz = quiz;
    state.shuffleQ = !!els.shuffleQuestions?.checked;
    state.shuffleC = !!els.shuffleChoices?.checked;
    state.showExplanations = !!els.showExplanations?.checked;

    if (state.shuffleQ) {
        shuffle(questions);
    }

    state.questions = questions.map((question) => {
        /** @type {Question} */
        const nextQuestion = {
            id: question.id,
            question: question.question,
            choices: Array.isArray(question.choices)
                ? question.choices.slice()
                : [],
            answer: question.answer,
            explanation: question.explanation,
        };

        if (state.shuffleC) {
            shuffle(nextQuestion.choices);
        }

        return nextQuestion;
    });

    state.currentIndex = 0;
    state.answers = new Array(state.questions.length).fill(null);
    state.results = [];

    if (els.quizTitle) {
        els.quizTitle.textContent = quiz.title;
    }

    if (els.restartBtn) {
        els.restartBtn.disabled = false;
    }

    setView(true, false);
    renderQuestion();
}

/* ── Quiz rendering ────────────────────────────────────────────── */

function renderQuestion() {
    const question = state.questions[state.currentIndex];
    if (!question) return;

    const total = state.questions.length;
    const answered = state.answers.filter((answer) => answer !== null).length;
    const currentAnswer = state.answers[state.currentIndex];

    if (els.questionCounter) {
        els.questionCounter.textContent = `Question ${
            state.currentIndex + 1
        } of ${total}`;
    }

    if (els.answeredCounter) {
        els.answeredCounter.textContent = `${answered} answered`;
    }

    if (els.scorePreview) {
        els.scorePreview.textContent = answered === 0
            ? "Not graded"
            : "In progress";
    }

    if (els.progressFill) {
        const pct = total > 0 ? ((state.currentIndex + 1) / total) * 100 : 0;
        els.progressFill.style.width = `${pct}%`;
    }

    if (els.questionText) {
        els.questionText.textContent = question.question;
    }

    if (els.choicesForm) {
        els.choicesForm.innerHTML = "";

        question.choices.forEach((choice, index) => {
            const id = `choice-${state.currentIndex}-${index}`;
            const label = document.createElement("label");
            label.className = "choice";

            const input = document.createElement("input");
            input.type = "radio";
            input.name = "choice";
            input.value = choice;
            input.id = id;
            input.checked = currentAnswer === choice;

            const span = document.createElement("span");
            span.textContent = choice;

            label.appendChild(input);
            label.appendChild(span);
            els.choicesForm?.appendChild(label);
        });
    }

    if (els.prevBtn) {
        els.prevBtn.disabled = state.currentIndex === 0;
    }

    els.nextBtn?.classList.toggle("hidden", state.currentIndex >= total - 1);
    els.submitBtn?.classList.toggle("hidden", state.currentIndex < total - 1);
}

function captureCurrentAnswer() {
    if (!els.choicesForm) return;

    const checked = els.choicesForm.querySelector(
        'input[name="choice"]:checked',
    );
    if (!checked) return;

    const input = /** @type {HTMLInputElement} */ (checked);
    state.answers[state.currentIndex] = input.value;
}

/* ── Results ───────────────────────────────────────────────────── */

function gradeQuiz() {
    state.results = state.questions.map((question, index) => ({
        question,
        selected: state.answers[index],
        correct: state.answers[index] === question.answer,
    }));
}

function showResults() {
    gradeQuiz();

    const total = state.results.length;
    const correct = state.results.filter((result) => result.correct).length;
    const pct = total > 0 ? Math.round((correct / total) * 100) : 0;

    if (els.resultsScore) {
        els.resultsScore.textContent = `${pct}%`;
    }

    if (els.resultsSummary) {
        els.resultsSummary.textContent = `${correct} of ${total} correct.`;
    }

    if (els.reviewList) {
        els.reviewList.innerHTML = "";

        state.results.forEach((result, index) => {
            const article = document.createElement("article");
            article.className = "review-item";

            const heading = document.createElement("h3");
            heading.textContent = `Question ${index + 1}`;

            const prompt = document.createElement("p");
            prompt.textContent = result.question.question;

            const yourAnswer = document.createElement("p");
            yourAnswer.innerHTML = `<strong>Your answer:</strong> ${
                escHtml(result.selected || "No answer")
            }`;

            const correctAnswer = document.createElement("p");
            correctAnswer.innerHTML = `<strong>Correct answer:</strong> ${
                escHtml(result.question.answer)
            }`;

            const outcome = document.createElement("p");
            outcome.innerHTML = `<strong>Result:</strong> ${
                result.correct ? "Correct" : "Incorrect"
            }`;

            article.appendChild(heading);
            article.appendChild(prompt);
            article.appendChild(yourAnswer);
            article.appendChild(correctAnswer);
            article.appendChild(outcome);

            if (state.showExplanations && result.question.explanation) {
                const explanation = document.createElement("p");
                explanation.innerHTML = `<strong>Explanation:</strong> ${
                    escHtml(result.question.explanation)
                }`;
                article.appendChild(explanation);
            }

            els.reviewList?.appendChild(article);
        });
    }

    setView(false, true);
}

/* ── Event binding ─────────────────────────────────────────────── */

function bindEvents() {
    els.quizSelect?.addEventListener("change", () => {
        updateQuizMeta();
    });

    els.startBtn?.addEventListener("click", async () => {
        const selectedId = els.quizSelect?.value;
        if (!selectedId) return;

        const quiz = quizCatalog.find((item) => item.id === selectedId);
        if (!quiz) return;

        try {
            await loadQuiz(quiz);
        } catch (error) {
            console.error(error);
            alert(
                error instanceof Error ? error.message : "Unable to load quiz.",
            );
        }
    });

    els.restartBtn?.addEventListener("click", async () => {
        if (!state.currentQuiz) return;

        try {
            await loadQuiz(state.currentQuiz);
        } catch (error) {
            console.error(error);
            alert(
                error instanceof Error
                    ? error.message
                    : "Unable to restart quiz.",
            );
        }
    });

    els.prevBtn?.addEventListener("click", () => {
        captureCurrentAnswer();

        if (state.currentIndex > 0) {
            state.currentIndex -= 1;
            renderQuestion();
        }
    });

    els.nextBtn?.addEventListener("click", () => {
        captureCurrentAnswer();

        if (state.currentIndex < state.questions.length - 1) {
            state.currentIndex += 1;
            renderQuestion();
        }
    });

    els.submitBtn?.addEventListener("click", () => {
        captureCurrentAnswer();
        showResults();
    });
}

/* ── Init ──────────────────────────────────────────────────────── */

async function init() {
    initTheme();
    bindEvents();

    try {
        await loadQuizCatalog();
        renderQuizSelect();
        updateQuizMeta();
    } catch (error) {
        console.error(error);

        if (els.quizMeta) {
            els.quizMeta.innerHTML = `
        <p><strong>Catalog unavailable.</strong></p>
        <p>Could not load <code>data/manifest.json</code>. Verify the workflow generated and deployed it.</p>
      `;
        }
    }
}

init();
