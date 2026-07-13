/* ── Types ───────────────────────────────────────────────────────── */

/**
 * @typedef {Object} QuizCatalogItem
 * @property {string} id
 * @property {string} title
 * @property {string} description
 * @property {string} file
 * @property {number|null} questionCount
 */

/**
 * @typedef {Object} QuestionExplanationChoice
 * @property {string} text
 * @property {string[]} [sections]
 */

/**
 * @typedef {Object} QuestionExplanationCorrect
 * @property {string} text
 * @property {string[]} [indexKeywords]
 * @property {string[]} [sections]
 */

/**
 * @typedef {Object} QuestionExplanationObject
 * @property {QuestionExplanationCorrect} [correct]
 * @property {Record<string, QuestionExplanationChoice>} [choices]
 */

/**
 * @typedef {Object} Question
 * @property {number|string} id
 * @property {string} question
 * @property {string[]} choices
 * @property {string} answer
 * @property {string|QuestionExplanationObject} [explanation]
 */

/**
 * @typedef {Object} QuizFile
 * @property {string} id
 * @property {string} title
 * @property {string} [version]
 * @property {string} [note]
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
 * @property {QuizCatalogItem|null} currentQuiz
 * @property {Question[]} questions
 * @property {number} currentIndex
 * @property {string|null} selected
 * @property {boolean} answered
 * @property {QuizResult[]} results
 * @property {boolean} shuffleQ
 * @property {boolean} shuffleC
 */

/* ── State ──────────────────────────────────────────────────────── */

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

/* ── DOM refs ───────────────────────────────────────────────────── */

/**
 * @param {string} sel
 * @returns {HTMLElement|null}
 */
const $ = (sel) => /** @type {HTMLElement|null} */ (document.querySelector(sel));

const views = {
  catalog: /** @type {HTMLElement} */ ($('#view-catalog')),
  quiz: /** @type {HTMLElement} */ ($('#view-quiz')),
  results: /** @type {HTMLElement} */ ($('#view-results')),
  review: /** @type {HTMLElement} */ ($('#view-review')),
};

/* ── Theme toggle ───────────────────────────────────────────────── */

(function () {
  /** @type {HTMLButtonElement|null} */
  const t = /** @type {HTMLButtonElement|null} */ ($('[data-theme-toggle]'));
  const r = document.documentElement;
  const prefersDark = window.matchMedia('(prefers-color-scheme: dark)').matches;
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
  function updateThemeIcon(btn, theme) {
    btn.setAttribute(
      'aria-label',
      'Switch to ' + (theme === 'dark' ? 'light' : 'dark') + ' mode'
    );
    btn.innerHTML =
      theme === 'dark'
        ? '☀️'
        : '🌙';
  }
})();

/* ── View management ────────────────────────────────────────────── */

/**
 * @param {ViewName} name
 */
function showView(name) {
  Object.values(views).forEach((v) => v.classList.remove('active'));
  views[name].classList.add('active');
  window.scrollTo({ top: 0, behavior: 'smooth' });
}

/* ── Catalog rendering ──────────────────────────────────────────── */

async function renderCatalog() {
  /** @type {HTMLDivElement} */
  const grid = /** @type {HTMLDivElement} */ ($('#quiz-catalog'));

  grid.innerHTML = '<p>Loading quizzes…</p>';

  /** @type {QuizCatalogItem[]} */
  let catalog = [];

  try {
    const res = await fetch('data/manifest.json');
    if (!res.ok) throw new Error(`manifest fetch failed: ${res.status}`);
    catalog = await res.json();
  } catch (err) {
    grid.innerHTML = `<p>Could not load quiz manifest. (${escHtml(err.message)})</p>`;
    return;
  }

  grid.innerHTML = '';

  if (catalog.length === 0) {
    grid.innerHTML = '<p>No quizzes found in manifest.</p>';
    return;
  }

  for (const quiz of catalog) {
    const count = quiz.questionCount ?? '?';
    const card = document.createElement('div');
    card.className = 'catalog-card';
    card.setAttribute('role', 'button');
    card.setAttribute('tabindex', '0');
    card.setAttribute('aria-label', 'Start ' + quiz.title);

    card.innerHTML = `
      <h3>${escHtml(quiz.title)}</h3>
      <p>${escHtml(quiz.description || '')}</p>
      <div class="catalog-meta">${count} questions</div>
      <button class="catalog-start-btn" type="button">Start test</button>
    `;

    const start = () => loadQuiz(quiz);

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

/* ── Load and start quiz ────────────────────────────────────────── */

/**
 * @param {QuizCatalogItem} quiz
 */
async function loadQuiz(quiz) {
  /** @type {QuizFile} */
  let data;

  try {
    const res = await fetch(quiz.file);
    if (!res.ok) throw new Error(`HTTP ${res.status}`);
    data = await res.json();
  } catch (err) {
    alert('Could not load quiz file: ' + quiz.file + '\n' + err.message);
    return;
  }

  /** @type {HTMLInputElement|null} */
  const shuffleQ = /** @type {HTMLInputElement|null} */ ($('#opt-shuffle-q'));
  /** @type {HTMLInputElement|null} */
  const shuffleC = /** @type {HTMLInputElement|null} */ ($('#opt-shuffle-c'));

  state.currentQuiz = quiz;
  state.shuffleQ = shuffleQ ? shuffleQ.checked : false;
  state.shuffleC = shuffleC ? shuffleC.checked : false;
  state.questions = data.questions.slice();

  if (state.shuffleQ) shuffle(state.questions);

  state.currentIndex = 0;
  state.results = [];
  state.selected = null;
  state.answered = false;

  /** @type {HTMLElement} */
  const quizTitleDisplay = /** @type {HTMLElement} */ ($('#quiz-title-display'));
  quizTitleDisplay.textContent = quiz.title;

  showView('quiz');
  renderQuestion();
}

/* ── Render question ────────────────────────────────────────────── */

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
  /** @type {HTMLUListElement} */
  const choicesList = /** @type {HTMLUListElement} */ ($('#choices-list'));
  /** @type {HTMLElement} */
  const feedback = /** @type {HTMLElement} */ ($('#feedback-area'));
  /** @type {HTMLButtonElement} */
  const submitBtn = /** @type {HTMLButtonElement} */ ($('#btn-submit'));
  /** @type {HTMLButtonElement} */
  const nextBtn = /** @type {HTMLButtonElement} */ ($('#btn-next'));

  progressLabel.textContent = `${done + 1} / ${total}`;
  progressBar.style.width = `${(done / total) * 100}%`;
  questionText.textContent = q.question;

  choicesList.innerHTML = '';

  /** @type {string[]} */
  let choices = q.choices.slice();
  if (state.shuffleC) shuffle(choices);

  const letters = ['A', 'B', 'C', 'D', 'E', 'F'];

  choices.forEach((choice, i) => {
    const li = document.createElement('li');
    li.className = 'choice-item';
    li.setAttribute('role', 'radio');
    li.setAttribute('aria-checked', 'false');
    li.setAttribute('tabindex', '0');
    li.dataset.value = choice;

    li.innerHTML = `
      <span class="choice-letter">${letters[i] || ''}</span>
      <span class="choice-text">${escHtml(choice)}</span>
    `;

    li.addEventListener('click', () => selectChoice(li, choice));
    li.addEventListener('keydown', (e) => {
      if (e.key === 'Enter' || e.key === ' ') {
        e.preventDefault();
        selectChoice(li, choice);
      }
    });

    choicesList.appendChild(li);
  });

  feedback.className = 'feedback-area hidden';
  feedback.innerHTML = '';

  submitBtn.disabled = true;
  submitBtn.classList.remove('hidden');
  nextBtn.classList.add('hidden');
}

/* ── Select choice ──────────────────────────────────────────────── */

/**
 * @param {HTMLLIElement} el
 * @param {string} value
 */
function selectChoice(el, value) {
  if (state.answered) return;

  state.selected = value;

  /** @type {NodeListOf<HTMLLIElement>} */
  const allChoices = document.querySelectorAll('#choices-list .choice-item');

  allChoices.forEach((item) => {
    item.classList.remove('selected');
    item.setAttribute('aria-checked', 'false');
  });

  el.classList.add('selected');
  el.setAttribute('aria-checked', 'true');

  /** @type {HTMLButtonElement} */
  const submitBtn = /** @type {HTMLButtonElement} */ ($('#btn-submit'));
  submitBtn.disabled = false;
}

/* ── Submit answer ──────────────────────────────────────────────── */

function submitAnswer() {
  if (state.answered || !state.selected) return;

  /** @type {Question} */
  const q = state.questions[state.currentIndex];
  const isCorrect = state.selected === q.answer;

  state.answered = true;

  state.results.push({
    question: q,
    selected: state.selected,
    correct: isCorrect,
  });

  /** @type {NodeListOf<HTMLLIElement>} */
  const allChoices = document.querySelectorAll('#choices-list .choice-item');

  allChoices.forEach((item) => {
    const value = item.dataset.value || '';
    item.classList.remove('selected');

    if (value === q.answer) {
      item.classList.add('correct');
    }

    if (value === state.selected && value !== q.answer) {
      item.classList.add('incorrect');
    }

    item.setAttribute('aria-checked', value === state.selected ? 'true' : 'false');
    item.setAttribute('tabindex', '-1');
  });

  /** @type {HTMLElement} */
  const feedback = /** @type {HTMLElement} */ ($('#feedback-area'));
  /** @type {HTMLButtonElement} */
  const submitBtn = /** @type {HTMLButtonElement} */ ($('#btn-submit'));
  /** @type {HTMLButtonElement} */
  const nextBtn = /** @type {HTMLButtonElement} */ ($('#btn-next'));

  const explanationText = getExplanationText(q, state.selected, isCorrect);
  const explanationMeta = getExplanationMeta(q, state.selected, isCorrect);

  feedback.className = `feedback-area ${isCorrect ? 'correct' : 'incorrect'}`;
  feedback.innerHTML = `
    <div class="feedback-title">${isCorrect ? 'Correct!' : 'Incorrect'}</div>
    <div class="feedback-answer">
      <strong>Correct answer:</strong> ${escHtml(q.answer)}
    </div>
    ${
      explanationText
        ? `<div class="feedback-text">${escHtml(explanationText)}</div>`
        : ''
    }
    ${
      explanationMeta
        ? `<div class="feedback-meta">${explanationMeta}</div>`
        : ''
    }
  `;

  submitBtn.classList.add('hidden');
  nextBtn.classList.remove('hidden');
  nextBtn.textContent =
    state.currentIndex === state.questions.length - 1 ? 'See results' : 'Next question';
}

/* ── Next question ──────────────────────────────────────────────── */

function nextQuestion() {
  if (!state.answered) return;

  if (state.currentIndex < state.questions.length - 1) {
    state.currentIndex += 1;
    renderQuestion();
    return;
  }

  renderResults();
}

/* ── Results ────────────────────────────────────────────────────── */

function renderResults() {
  const total = state.results.length;
  const correct = state.results.filter((r) => r.correct).length;
  const percent = total === 0 ? 0 : Math.round((correct / total) * 100);

  /** @type {HTMLElement} */
  const scoreValue = /** @type {HTMLElement} */ ($('#score-value'));
  /** @type {HTMLElement} */
  const scoreDetail = /** @type {HTMLElement} */ ($('#score-detail'));
  /** @type {HTMLElement} */
  const resultsList = /** @type {HTMLElement} */ ($('#results-list'));

  scoreValue.textContent = `${percent}%`;
  scoreDetail.textContent = `${correct} of ${total} correct`;

  resultsList.innerHTML = '';

  state.results.forEach((r, index) => {
    const item = document.createElement('div');
    item.className = `result-item ${r.correct ? 'correct' : 'incorrect'}`;

    item.innerHTML = `
      <div class="result-number">Q${index + 1}</div>
      <div class="result-body">
        <div class="result-question">${escHtml(r.question.question)}</div>
        <div class="result-selected">
          <strong>Your answer:</strong> ${escHtml(r.selected)}
        </div>
        <div class="result-correct-answer">
          <strong>Correct answer:</strong> ${escHtml(r.question.answer)}
        </div>
        <div class="result-status">${r.correct ? 'Correct' : 'Incorrect'}</div>
      </div>
    `;

    resultsList.appendChild(item);
  });

  showView('results');
}

/* ── Review ─────────────────────────────────────────────────────── */

function renderReview() {
  /** @type {HTMLElement} */
  const list = /** @type {HTMLElement} */ ($('#review-list'));
  list.innerHTML = '';

  state.results.forEach((r, index) => {
    const explanationText = getExplanationText(r.question, r.selected, r.correct);
    const explanationMeta = getExplanationMeta(r.question, r.selected, r.correct);

    const div = document.createElement('div');
    div.className = `review-item ${r.correct ? 'correct' : 'incorrect'}`;

    div.innerHTML = `
      <div class="review-header">
        <div class="review-number">Question ${index + 1}</div>
        <div class="review-status">${r.correct ? 'Correct' : 'Incorrect'}</div>
      </div>
      <div class="review-question">${escHtml(r.question.question)}</div>
      <div class="review-selected"><strong>Your answer:</strong> ${escHtml(r.selected)}</div>
      <div class="review-answer"><strong>Correct answer:</strong> ${escHtml(r.question.answer)}</div>
      ${
        explanationText
          ? `<div class="review-explanation">${escHtml(explanationText)}</div>`
          : ''
      }
      ${
        explanationMeta
          ? `<div class="review-meta">${explanationMeta}</div>`
          : ''
      }
    `;

    list.appendChild(div);
  });

  showView('review');
}

/* ── Explanation helpers ────────────────────────────────────────── */

/**
 * @param {Question} question
 * @param {string|null} selected
 * @param {boolean} isCorrect
 * @returns {string}
 */
function getExplanationText(question, selected, isCorrect) {
  const exp = question.explanation;

  if (!exp) return '';

  if (typeof exp === 'string') {
    return exp;
  }

  if (isCorrect) {
    return exp.correct?.text || '';
  }

  if (selected && exp.choices && exp.choices[selected]) {
    return exp.choices[selected].text || '';
  }

  return exp.correct?.text || '';
}

/**
 * @param {Question} question
 * @param {string|null} selected
 * @param {boolean} isCorrect
 * @returns {string}
 */
function getExplanationMeta(question, selected, isCorrect) {
  const exp = question.explanation;

  if (!exp || typeof exp === 'string') return '';

  let sections = [];
  let keywords = [];

  if (isCorrect) {
    sections = exp.correct?.sections || [];
    keywords = exp.correct?.indexKeywords || [];
  } else if (selected && exp.choices && exp.choices[selected]) {
    sections = exp.choices[selected].sections || [];
  }

  const parts = [];

  if (sections.length) {
    parts.push(
      `<span class="meta-sections"><strong>Sections:</strong> ${escHtml(
        sections.join(', ')
      )}</span>`
    );
  }

  if (keywords.length) {
    parts.push(
      `<span class="meta-keywords"><strong>Index:</strong> ${escHtml(
        keywords.join(' | ')
      )}</span>`
    );
  }

  return parts.join(' ');
}

/* ── Buttons / events ───────────────────────────────────────────── */

(function bindEvents() {
  /** @type {HTMLButtonElement|null} */
  const submitBtn = /** @type {HTMLButtonElement|null} */ ($('#btn-submit'));
  /** @type {HTMLButtonElement|null} */
  const nextBtn = /** @type {HTMLButtonElement|null} */ ($('#btn-next'));
  /** @type {HTMLButtonElement|null} */
  const reviewBtn = /** @type {HTMLButtonElement|null} */ ($('#btn-review'));
  /** @type {HTMLButtonElement|null} */
  const retryBtn = /** @type {HTMLButtonElement|null} */ ($('#btn-retry'));
  /** @type {HTMLButtonElement|null} */
  const homeBtns = /** @type {NodeListOf<HTMLButtonElement>} */ (document.querySelectorAll('[data-action="home"]'));

  if (submitBtn) {
    submitBtn.addEventListener('click', submitAnswer);
  }

  if (nextBtn) {
    nextBtn.addEventListener('click', nextQuestion);
  }

  if (reviewBtn) {
    reviewBtn.addEventListener('click', renderReview);
  }

  if (retryBtn) {
    retryBtn.addEventListener('click', () => {
      if (state.currentQuiz) {
        loadQuiz(state.currentQuiz);
      }
    });
  }

  homeBtns.forEach((btn) => {
    btn.addEventListener('click', () => {
      showView('catalog');
    });
  });
})();

/* ── Utilities ──────────────────────────────────────────────────── */

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
    .replace(/&/g, '&amp;')
    .replace(/</g, '&lt;')
    .replace(/>/g, '&gt;')
    .replace(/"/g, '&quot;')
    .replace(/'/g, '&#39;');
}

/* ── Init ───────────────────────────────────────────────────────── */

renderCatalog();
