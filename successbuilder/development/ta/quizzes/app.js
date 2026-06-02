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
 * @property {number | string} id
 * @property {string} question
 * @property {string[]} choices
 * @property {string} answer
 * @property {string} [explanation]
 */

/**
 * @typedef {Object} QuizFile
 * @property {string} id
 * @property {string} title
 * @property {string} [description]
 * @property {Question[]} questions
 */

/**
 * @typedef {Object} QuizResult
 * @property {Question} question
 * @property {string} selected
 * @property {boolean} correct
 */

/**
 * @typedef {'catalog' | 'quiz' | 'results' | 'review'} ViewName
 */

/**
 * @typedef {Object} AppState
 * @property {QuizCatalogItem | null} currentQuiz
 * @property {Question[]} questions
 * @property {number} currentIndex
 * @property {string | null} selected
 * @property {boolean} answered
 * @property {QuizResult[]} results
 * @property {boolean} shuffleQ
 * @property {boolean} shuffleC
 */

/* ── Catalog + state ───────────────────────────────────────────── */

let quizCatalog = [];

/** @type {AppState} */
let state = {
  currentQuiz: null,
  questions: [],
  currentIndex: 0,
  selected: null,
  answered: false,
  results: [],
  shuffleQ: false,
  shuffleC: false,
};

/* ── DOM helpers ───────────────────────────────────────────────── */

/**
 * @param {string} sel
 * @returns {Element | null}
 */
const $ = (sel) => document.querySelector(sel);

const views = {
  catalog: /** @type {HTMLElement} */ ($('#view-catalog')),
  quiz: /** @type {HTMLElement} */ ($('#view-quiz')),
  results: /** @type {HTMLElement} */ ($('#view-results')),
  review: /** @type {HTMLElement} */ ($('#view-review')),
};

/* ── Theme toggle ──────────────────────────────────────────────── */

(() => {
  /** @type {HTMLButtonElement | null} */
  const t = /** @type {HTMLButtonElement | null} */ ($('[data-theme-toggle]'));
  const r = document.documentElement;
  const prefersDark = matchMedia('(prefers-color-scheme: dark)').matches;
  let d = r.getAttribute('data-theme') || (prefersDark ? 'dark' : 'light');

  r.setAttribute('data-theme', d);

  if (t) {
    updateThemeIcon(t, d);
    t.addEventListener('click', () => {
      d = d === 'dark' ? 'light' : 'dark';
      r.setAttribute('data-theme', d);
      updateThemeIcon(t, d);
    });
  }

  /**
   * @param {HTMLButtonElement} btn
   * @param {string} theme
   */
  const updateThemeIcon = (btn, theme) => {
    btn.setAttribute(
      'aria-label',
      `Switch to ${theme === 'dark' ? 'light' : 'dark'} mode`,
    );

    btn.innerHTML =
      theme === 'dark'
        ? '<svg width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><circle cx="12" cy="12" r="5"/><path d="M12 1v2M12 21v2M4.22 4.22l1.42 1.42M18.36 18.36l1.42 1.42M1 12h2M21 12h2M4.22 19.78l1.42-1.42M18.36 5.64l1.42-1.42"/></svg>'
        : '<svg width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><path d="M21 12.79A9 9 0 1 1 11.21 3 7 7 0 0 0 21 12.79z"/></svg>';
  };
})();

/* ── View management ───────────────────────────────────────────── */

/**
 * @param {ViewName} name
 */
function showView(name) {
  Object.values(views).forEach((v) => {
    v.classList.remove('active');
  });

  views[name].classList.add('active');
  window.scrollTo({ top: 0, behavior: 'smooth' });
}

/* ── Catalog manifest loading ──────────────────────────────────── */

async function loadQuizCatalog() {
  const response = await fetch(`data/manifest.json?v=${Date.now()}`);

  if (!response.ok) {
    throw new Error(`Unable to load quiz manifest (${response.status})`);
  }

  const data = await response.json();
  quizCatalog = Array.isArray(data) ? data : [];
}

function ensureQuizCatalog() {
  if (!Array.isArray(quizCatalog) || quizCatalog.length === 0) {
    throw new Error('No quizzes found in manifest.json');
  }
}

/* ── Catalog rendering ─────────────────────────────────────────── */

async function renderCatalog() {
  /** @type {HTMLDivElement} */
  const grid = /** @type {HTMLDivElement} */ ($('#quiz-catalog'));

  grid.innerHTML = '';

  for (const quiz of quizCatalog) {
    const count = quiz.questionCount ?? '?';

    const card = document.createElement('div');
    card.className = 'catalog-card';
    card.setAttribute('role', 'button');
    card.setAttribute('tabindex', '0');
    card.setAttribute('aria-label', `Start ${quiz.title}`);

    card.innerHTML = `
      <svg class="catalog-card-icon" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.5">
        <path d="M9 5H7a2 2 0 0 0-2 2v12a2 2 0 0 0 2 2h10a2 2 0 0 0 2-2V7a2 2 0 0 0-2-2h-2M9 5a2 2 0 0 0 2 2h2a2 2 0 0 0 2-2M9 5a2 2 0 0 1 2-2h2a2 2 0 0 1 2 2m-6 9l2 2 4-4"/>
      </svg>
      <div class="catalog-card-title">${escHtml(quiz.title)}</div>
      <div class="catalog-card-meta">${count} question${count === 1 ? '' : 's'}</div>
      <p style="font-size:var(--text-xs);color:var(--color-text-muted);max-width:36ch;margin-bottom:var(--space-4);">${escHtml(quiz.description)}</p>
      <span class="catalog-card-cta">Start test
        <svg width="14" height="14" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><polyline points="9,18 15,12 9,6"/></svg>
      </span>
    `;

    const start = () => {
      loadQuiz(quiz);
    };

    card.addEventListener('click', start);
    card.addEventListener('keydown', (e) => {
      if (e.key === 'Enter' || e.key === ' ') {
        e.preventDefault();
        start();
      }
    });

    grid.appendChild(card);
  }
}

/* ── Quiz loading ──────────────────────────────────────────────── */

/**
 * @param {QuizCatalogItem} quiz
 */
async function loadQuiz(quiz) {
  /** @type {QuizFile} */
  let data;

  try {
    const res = await fetch(`${quiz.file}?v=${Date.now()}`);
    if (!res.ok) {
      throw new Error(`HTTP ${res.status}`);
    }
    data = await res.json();
  } catch {
    alert(`Could not load quiz file: ${quiz.file}`);
    return;
  }

  /** @type {HTMLInputElement | null} */
  const shuffleQ = /** @type {HTMLInputElement | null} */ ($('#shuffle-questions'));

  /** @type {HTMLInputElement | null} */
  const shuffleC = /** @type {HTMLInputElement | null} */ ($('#shuffle-choices'));

  state.currentQuiz = quiz;
  state.shuffleQ = shuffleQ ? shuffleQ.checked : false;
  state.shuffleC = shuffleC ? shuffleC.checked : false;
  state.questions = Array.isArray(data.questions) ? data.questions.slice() : [];

  if (state.shuffleQ) {
    shuffle(state.questions);
  }

  state.currentIndex = 0;
  state.results = [];

  /** @type {HTMLElement} */
  const quizTitleDisplay = /** @type {HTMLElement} */ ($('#quiz-title'));
  quizTitleDisplay.textContent = quiz.title;

  showView('quiz');
  renderQuestion();
}

/* ── Render question ───────────────────────────────────────────── */

function renderQuestion() {
  /** @type {Question} */
  const q = state.questions[state.currentIndex];

  state.selected = null;
  state.answered = false;

  const total = state.questions.length;
  const done = state.currentIndex;

  /** @type {HTMLElement} */
  const progressLabel = /** @type {HTMLElement} */ ($('#progress-label'));

  /** @type {HTMLElement} */
  const progressBar = /** @type {HTMLElement} */ ($('#progress-bar'));

  /** @type {HTMLElement} */
  const questionText = /** @type {HTMLElement} */ ($('#question-text'));

  progressLabel.textContent = `${done + 1} / ${total}`;
  progressBar.style.width = `${(done / total) * 100}%`;
  questionText.textContent = q.question;

  /** @type {HTMLUListElement} */
  const choicesList = /** @type {HTMLUListElement} */ ($('#choices-list'));
  choicesList.innerHTML = '';

  /** @type {string[]} */
  let choices = q.choices.slice();

  if (state.shuffleC) {
    shuffle(choices);
  }

  const letters = ['A', 'B', 'C', 'D', 'E', 'F'];

  choices.forEach((choice, i) => {
    const li = document.createElement('li');
    li.className = 'choice-item';
    li.setAttribute('role', 'radio');
    li.setAttribute('aria-checked', 'false');
    li.setAttribute('tabindex', '0');
    li.dataset.value = choice;

    li.innerHTML = `
      <span class="choice-letter" aria-hidden="true">${letters[i] || i + 1}</span>
      <span class="choice-text">${escHtml(choice)}</span>
    `;

    li.addEventListener('click', () => {
      selectChoice(li, choice);
    });

    li.addEventListener('keydown', (e) => {
      if (e.key === 'Enter' || e.key === ' ') {
        e.preventDefault();
        selectChoice(li, choice);
      }
    });

    choicesList.appendChild(li);
  });

  /** @type {HTMLElement} */
  const feedback = /** @type {HTMLElement} */ ($('#feedback'));
  feedback.className = 'feedback-area hidden';
  feedback.innerHTML = '';

  /** @type {HTMLButtonElement} */
  const submitBtn = /** @type {HTMLButtonElement} */ ($('#submit-btn'));

  /** @type {HTMLButtonElement} */
  const nextBtn = /** @type {HTMLButtonElement} */ ($('#next-btn'));

  submitBtn.disabled = true;
  submitBtn.classList.remove('hidden');
  nextBtn.classList.add('hidden');
}

/* ── Select choice ─────────────────────────────────────────────── */

/**
 * @param {HTMLLIElement} el
 * @param {string} value
 */
function selectChoice(el, value) {
  if (state.answered) {
    return;
  }

  state.selected = value;

  /** @type {NodeListOf<HTMLElement>} */
  const choiceItems = /** @type {NodeListOf<HTMLElement>} */ (document.querySelectorAll('.choice-item'));

  choiceItems.forEach((item) => {
    item.classList.remove('selected');
    item.setAttribute('aria-checked', 'false');
  });

  el.classList.add('selected');
  el.setAttribute('aria-checked', 'true');

  /** @type {HTMLButtonElement} */
  const submitBtn = /** @type {HTMLButtonElement} */ ($('#submit-btn'));
  submitBtn.disabled = false;
}

/* ── Submit answer ─────────────────────────────────────────────── */

{
  /** @type {HTMLButtonElement} */
  const submitBtn = /** @type {HTMLButtonElement} */ ($('#submit-btn'));

  submitBtn.addEventListener('click', () => {
    if (!state.selected || state.answered) {
      return;
    }

    state.answered = true;

    /** @type {Question} */
    const q = state.questions[state.currentIndex];
    const correct = state.selected === q.answer;

    state.results.push({
      question: q,
      selected: state.selected,
      correct,
    });

    /** @type {NodeListOf<HTMLLIElement>} */
    const choiceItems = /** @type {NodeListOf<HTMLLIElement>} */ (document.querySelectorAll('.choice-item'));

    choiceItems.forEach((item) => {
      item.classList.add('disabled');
      item.setAttribute('tabindex', '-1');

      if (item.dataset.value === q.answer) {
        item.classList.add('correct');
      } else if (item.dataset.value === state.selected && !correct) {
        item.classList.add('wrong');
      }

      item.classList.remove('selected');
    });

    /** @type {HTMLElement} */
    const feedback = /** @type {HTMLElement} */ ($('#feedback'));

    /** @type {HTMLButtonElement} */
    const nextBtn = /** @type {HTMLButtonElement} */ ($('#next-btn'));

    feedback.className = `feedback-area ${correct ? 'correct-fb' : 'wrong-fb'}`;

    if (correct) {
      feedback.innerHTML =
        `<strong class="feedback-strong">Correct!</strong>${q.explanation ? escHtml(q.explanation) : ''
        }`;
    } else {
      feedback.innerHTML =
        `<strong class="feedback-strong">Incorrect.</strong>Correct answer: <strong>${escHtml(q.answer)}</strong>${q.explanation ? `<br>${escHtml(q.explanation)}` : ''
        }`;
    }

    submitBtn.classList.add('hidden');
    nextBtn.classList.remove('hidden');
  });
}

/* ── Next question ─────────────────────────────────────────────── */

{
  /** @type {HTMLButtonElement} */
  const nextBtn = /** @type {HTMLButtonElement} */ ($('#next-btn'));

  nextBtn.addEventListener('click', () => {
    state.currentIndex += 1;

    if (state.currentIndex >= state.questions.length) {
      showResults();
    } else {
      renderQuestion();
    }
  });
}

/* ── Back buttons ──────────────────────────────────────────────── */

{
  /** @type {HTMLButtonElement} */
  const backToCatalog = /** @type {HTMLButtonElement} */ ($('#back-to-catalog'));

  /** @type {HTMLButtonElement} */
  const backFromResults = /** @type {HTMLButtonElement} */ ($('#back-from-results'));

  /** @type {HTMLButtonElement} */
  const backFromReview = /** @type {HTMLButtonElement} */ ($('#back-from-review'));

  backToCatalog.addEventListener('click', () => {
    showView('catalog');
  });

  backFromResults.addEventListener('click', () => {
    showView('catalog');
  });

  backFromReview.addEventListener('click', () => {
    showView('results');
  });
}

/* ── Results ───────────────────────────────────────────────────── */

function showResults() {
  const total = state.results.length;
  const correct = state.results.filter((r) => r.correct).length;
  const pct = Math.round((correct / total) * 100);

  const circumference = 326.7;
  const offset = circumference - (pct / 100) * circumference;

  /** @type {SVGCircleElement} */
  const scoreArc = /** @type {SVGCircleElement} */ ($('#score-arc'));

  /** @type {HTMLElement} */
  const scorePct = /** @type {HTMLElement} */ ($('#score-pct'));

  /** @type {HTMLElement} */
  const resultsHeading = /** @type {HTMLElement} */ ($('#results-heading'));

  /** @type {HTMLElement} */
  const resultsSub = /** @type {HTMLElement} */ ($('#results-sub'));

  setTimeout(() => {
    scoreArc.style.strokeDashoffset = String(offset);
  }, 100);

  if (pct >= 80) {
    scoreArc.style.stroke = 'var(--color-correct)';
  } else if (pct >= 60) {
    scoreArc.style.stroke = 'var(--color-primary)';
  } else {
    scoreArc.style.stroke = 'var(--color-wrong)';
  }

  scorePct.textContent = `${pct}%`;

  const heading =
    pct >= 90
      ? 'Outstanding work.'
      : pct >= 80
        ? 'Well done!'
        : pct >= 70
          ? 'Good progress.'
          : pct >= 60
            ? 'Keep studying.'
            : 'More review needed.';

  resultsHeading.textContent = heading;
  resultsSub.textContent = `${correct} of ${total} correct. Verify answers against source material before relying on results for exam prep.`;

  showView('results');
}

/* ── Retake ────────────────────────────────────────────────────── */

{
  /** @type {HTMLButtonElement} */
  const retakeBtn = /** @type {HTMLButtonElement} */ ($('#retake-btn'));

  retakeBtn.addEventListener('click', () => {
    if (state.currentQuiz) {
      loadQuiz(state.currentQuiz);
    }
  });
}

/* ── Review ────────────────────────────────────────────────────── */

{
  /** @type {HTMLButtonElement} */
  const reviewBtn = /** @type {HTMLButtonElement} */ ($('#review-btn'));

  reviewBtn.addEventListener('click', () => {
    /** @type {HTMLDivElement} */
    const list = /** @type {HTMLDivElement} */ ($('#review-list'));
    list.innerHTML = '';

    state.results.forEach((r, i) => {
      const div = document.createElement('div');
      div.className = `review-item ${r.correct ? 'r-correct' : 'r-wrong'}`;

      const choicesHtml = r.question.choices
        .map((c) => {
          const isCorrect = c === r.question.answer;
          const isSelected = c === r.selected;

          if (!isCorrect && !isSelected) {
            return '';
          }

          const cls = isCorrect ? 'ra-correct' : 'ra-wrong';
          const badge = isCorrect
            ? '<span class="badge badge-correct">Correct answer</span>'
            : '<span class="badge badge-wrong">Your answer</span>';

          return `<div class="review-answer ${cls}">${badge} <span>${escHtml(c)}</span></div>`;
        })
        .join('');

      div.innerHTML = `
        <div class="review-q-num">Question ${i + 1}</div>
        <p class="review-q-text">${escHtml(r.question.question)}</p>
        <div class="review-answers">${choicesHtml}</div>
        ${r.question.explanation
          ? `<p class="review-explanation">${escHtml(r.question.explanation)}</p>`
          : ''
        }
      `;

      list.appendChild(div);
    });

    showView('review');
  });
}

/* ── Utilities ─────────────────────────────────────────────────── */

/**
 * @template T
 * @param {T[]} arr
 * @returns {T[]}
 */
function shuffle(arr) {
  for (let i = arr.length - 1; i > 0; i -= 1) {
    const j = Math.floor(Math.random() * (i + 1));
    [arr[i], arr[j]] = [arr[j], arr[i]];
  }

  return arr;
}

/**
 * @param {string} str
 * @returns {string}
 */
function escHtml(str) {
  return String(str)
    .replaceAll('&', '&amp;')
    .replaceAll('<', '&lt;')
    .replaceAll('>', '&gt;')
    .replaceAll('"', '&quot;');
}

/* ── Init ──────────────────────────────────────────────────────── */

async function init() {
  try {
    await loadQuizCatalog();
    ensureQuizCatalog();
    await renderCatalog();
  } catch (error) {
    console.error(error);

    /** @type {HTMLDivElement | null} */
    const grid = /** @type {HTMLDivElement | null} */ ($('#quiz-catalog'));

    if (grid) {
      grid.innerHTML = `
        <div class="catalog-card">
          <div class="catalog-card-title">Catalog unavailable</div>
          <p style="font-size:var(--text-xs);color:var(--color-text-muted);max-width:36ch;margin-bottom:var(--space-4);">
            Could not load data/manifest.json. Make sure your workflow generated it and that the file was deployed.
          </p>
        </div>
      `;
    }
  }
}

init();
