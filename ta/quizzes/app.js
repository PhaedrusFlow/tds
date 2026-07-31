/* ── Types ───────────────────────────────────────────────────────── */

/**
 * @typedef {Object} QuizCatalogItem
 * @property {string} id
 * @property {string} title
 * @property {string} description
 * @property {string} file
 * @property {number|null} [questionCount]
 * @property {'practice'|'mock'} mode
 * @property {boolean} requiresPassword
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
 * @property {string} [id]
 * @property {string} [title]
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
 * @typedef {'catalog'|'quiz'|'results'|'review'} ViewName
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
 * @property {QuizCatalogItem[]} catalog
 */

const state = {
  currentQuiz: null,
  questions: [],
  currentIndex: 0,
  selected: null,
  answered: false,
  results: [],
  shuffleQ: false,
  shuffleC: false,
  catalog: [],
};

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

const els = {
  catalog: /** @type {HTMLDivElement} */ ($('#quiz-catalog')),
  quizTitle: /** @type {HTMLElement} */ ($('#quiz-title-display')),
  progressLabel: /** @type {HTMLElement} */ ($('#progress-label')),
  progressBar: /** @type {HTMLElement} */ ($('#progress-bar')),
  questionText: /** @type {HTMLElement} */ ($('#question-text')),
  choicesList: /** @type {HTMLUListElement} */ ($('#choices-list')),
  feedbackArea: /** @type {HTMLElement} */ ($('#feedback-area')),
  submitBtn: /** @type {HTMLButtonElement} */ ($('#btn-submit')),
  nextBtn: /** @type {HTMLButtonElement} */ ($('#btn-next')),
  shuffleQ: /** @type {HTMLInputElement|null} */ ($('#opt-shuffle-q')),
  shuffleC: /** @type {HTMLInputElement|null} */ ($('#opt-shuffle-c')),
  scoreValue: /** @type {HTMLElement} */ ($('#score-value')),
  scoreDetail: /** @type {HTMLElement} */ ($('#score-detail')),
  scoreArc: /** @type {SVGCircleElement|null} */ ($('#score-arc')),
  resultsHeading: /** @type {HTMLElement} */ ($('#results-heading')),
  resultsList: /** @type {HTMLElement} */ ($('#results-list')),
  reviewList: /** @type {HTMLElement} */ ($('#review-list')),
  reviewBtn: /** @type {HTMLButtonElement|null} */ ($('#btn-review')),
  retryBtn: /** @type {HTMLButtonElement|null} */ ($('#btn-retry')),
  backFromReviewBtn: /** @type {HTMLButtonElement|null} */ ($('#btn-back-from-review')),
};

const MANIFEST_PATH = './data/manifest.json';
const MOCK_CONFIG_PATH = './mock-config.json';
const MOCK_AUTH_SESSION_KEY = 'tds.pretest-c.authorized';

(function initTheme() {
  /** @type {HTMLButtonElement|null} */
  const btn = /** @type {HTMLButtonElement|null} */ ($('[data-theme-toggle]'));
  const root = document.documentElement;
  const prefersDark = window.matchMedia('(prefers-color-scheme: dark)').matches;
  let theme = root.getAttribute('data-theme') || (prefersDark ? 'dark' : 'light');

  root.setAttribute('data-theme', theme);

  if (btn) {
    setThemeIcon(btn, theme);
    btn.addEventListener('click', () => {
      theme = theme === 'dark' ? 'light' : 'dark';
      root.setAttribute('data-theme', theme);
      setThemeIcon(btn, theme);
    });
  }

  /**
   * @param {HTMLButtonElement} button
   * @param {string} currentTheme
   */
  function setThemeIcon(button, currentTheme) {
    button.setAttribute(
      'aria-label',
      `Switch to ${currentTheme === 'dark' ? 'light' : 'dark'} mode`
    );
    button.innerHTML =
      currentTheme === 'dark'
        ? `<svg width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
             <circle cx="12" cy="12" r="5"></circle>
             <path d="M12 1v2M12 21v2M4.22 4.22l1.42 1.42M18.36 18.36l1.42 1.42M1 12h2M21 12h2M4.22 19.78l1.42-1.42M18.36 5.64l1.42-1.42"></path>
           </svg>`
        : `<svg width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2">
             <path d="M21 12.79A9 9 0 1 1 11.21 3 7 7 0 0 0 21 12.79z"></path>
           </svg>`;
  }
})();

/**
 * @param {ViewName} name
 */
function showView(name) {
  Object.values(views).forEach((view) => view.classList.remove('active'));
  views[name].classList.add('active');
  window.scrollTo({ top: 0, behavior: 'smooth' });
}

/**
 * @param {string} path
 * @returns {string}
 */
function normalizePath(path) {
  if (!path) return path;
  if (/^(https?:)?\/\//i.test(path)) return path;
  if (path.startsWith('./') || path.startsWith('../') || path.startsWith('/')) return path;
  return `./${path}`;
}

async function renderCatalog() {
  els.catalog.innerHTML = `<p>Loading quizzes…</p>`;

  try {
    const res = await fetch(MANIFEST_PATH, { cache: 'no-store' });
    if (!res.ok) {
      throw new Error(`Manifest request failed (${res.status}) at ${MANIFEST_PATH}`);
    }

    /** @type {unknown} */
    const payload = await res.json();

    if (!Array.isArray(payload)) {
      throw new Error('Manifest must be a JSON array.');
    }

    state.catalog = payload
      .filter(Boolean)
      .map((item) => ({
        id: String(item.id ?? ''),
        title: String(item.title ?? 'Untitled quiz'),
        description: String(item.description ?? ''),
        file: normalizePath(String(item.file ?? '')),
        questionCount:
          item.questionCount === null || item.questionCount === undefined
            ? null
            : Number(item.questionCount),
        mode: item.mode === 'mock' ? 'mock' : 'practice',
        requiresPassword: item.requiresPassword === true,
      }))
      .filter((item) => item.id && item.file);

    if (state.catalog.length === 0) {
      els.catalog.innerHTML = `
        <div class="results-card">
          <h2 class="results-heading">No tests found</h2>
          <p class="results-sub">
            The manifest loaded, but it did not contain any usable quiz entries.
          </p>
        </div>
      `;
      return;
    }

    els.catalog.innerHTML = '';
    state.catalog.forEach((quiz) => {
      els.catalog.appendChild(createCatalogCard(quiz));
    });
  } catch (err) {
    const message = err instanceof Error ? err.message : String(err);
    els.catalog.innerHTML = `
      <div class="results-card">
        <h2 class="results-heading">Could not load tests</h2>
        <p class="results-sub">
          Check that <code>${escHtml(MANIFEST_PATH)}</code> exists and that your quiz JSON files are in the <code>data/</code> folder.
        </p>
        <div class="results-list">
          <div class="result-item incorrect">
            <div class="result-number">!</div>
            <div class="result-body">
              <div class="result-question">Load error</div>
              <div class="result-status">${escHtml(message)}</div>
            </div>
          </div>
        </div>
      </div>
    `;
  }
}

/**
 * @param {QuizCatalogItem} quiz
 * @returns {HTMLDivElement}
 */
function createCatalogCard(quiz) {
  const card = document.createElement('div');
  const count =
    typeof quiz.questionCount === 'number' && Number.isFinite(quiz.questionCount)
      ? quiz.questionCount
      : '?';

  card.className = 'catalog-card';
  card.setAttribute('role', 'button');
  card.setAttribute('tabindex', '0');
  card.setAttribute('aria-label', `Start ${quiz.title}`);

  card.innerHTML = `
    <h3>${escHtml(quiz.title)}</h3>
    <p>${escHtml(quiz.description || '')}</p>
    <div class="catalog-meta">
      ${escHtml(String(count))} questions
      ${quiz.mode === 'mock' ? ' · Mock test' : ''}
      ${quiz.requiresPassword ? ' · Access code required' : ''}
    </div>
    <button class="catalog-start-btn" type="button" tabindex="-1">Start test</button>
  `;

  const start = () => loadQuiz(quiz);

  card.addEventListener('click', start);
  card.addEventListener('keydown', (event) => {
    if (event.key === 'Enter' || event.key === ' ') {
      event.preventDefault();
      start();
    }
  });

  return card;
}

/**
 * @param {QuizCatalogItem} quiz
 */
async function loadQuiz(quiz) {
  try {
    if (quiz.requiresPassword && !(await authorizeMockQuiz())) {
      return;
    }

    const res = await fetch(normalizePath(quiz.file), { cache: 'no-store' });
    if (!res.ok) {
      throw new Error(`Quiz request failed (${res.status}) for ${quiz.file}`);
    }

    /** @type {QuizFile} */
    const data = await res.json();

    if (!data || !Array.isArray(data.questions)) {
      throw new Error(`Quiz file ${quiz.file} is missing a questions array.`);
    }

    state.currentQuiz = quiz;
    state.shuffleQ = !!els.shuffleQ?.checked;
    state.shuffleC = !!els.shuffleC?.checked;
    state.questions = data.questions.slice();

    if (state.shuffleQ) {
      shuffle(state.questions);
    }

    if (state.questions.length === 0) {
      throw new Error(`Quiz file ${quiz.file} contains 0 questions.`);
    }

    state.currentIndex = 0;
    state.results = [];
    state.selected = null;
    state.answered = false;

    els.quizTitle.textContent = quiz.title;
    showView('quiz');
    renderQuestion();
  } catch (err) {
    const message = err instanceof Error ? err.message : String(err);
    els.catalog.innerHTML = `
      <div class="results-card">
        <h2 class="results-heading">Could not open quiz</h2>
        <p class="results-sub">
          The selected test could not be loaded.
        </p>
        <div class="results-list">
          <div class="result-item incorrect">
            <div class="result-number">!</div>
            <div class="result-body">
              <div class="result-question">${escHtml(quiz.title)}</div>
              <div class="result-selected"><strong>File:</strong> ${escHtml(quiz.file)}</div>
              <div class="result-status">${escHtml(message)}</div>
            </div>
          </div>
        </div>
      </div>
    `;
    showView('catalog');
  }
}

function renderQuestion() {
  const q = state.questions[state.currentIndex];
  state.selected = null;
  state.answered = false;

  const total = state.questions.length;
  const currentNumber = state.currentIndex + 1;
  const progressPercent = total > 0 ? ((currentNumber - 1) / total) * 100 : 0;

  els.progressLabel.textContent = `${currentNumber} / ${total}`;
  els.progressBar.style.width = `${progressPercent}%`;
  els.questionText.textContent = q.question;
  els.choicesList.innerHTML = '';

  let choices = q.choices.slice();
  if (state.shuffleC) {
    shuffle(choices);
  }

  const letters = ['A', 'B', 'C', 'D', 'E', 'F'];

  choices.forEach((choice, index) => {
    const li = document.createElement('li');
    li.className = 'choice-item';
    li.setAttribute('role', 'radio');
    li.setAttribute('aria-checked', 'false');
    li.setAttribute('tabindex', '0');
    li.dataset.value = choice;

    li.innerHTML = `
      <span class="choice-letter">${escHtml(letters[index] || '')}</span>
      <span class="choice-text">${escHtml(choice)}</span>
    `;

    li.addEventListener('click', () => selectChoice(li, choice));
    li.addEventListener('keydown', (event) => {
      if (event.key === 'Enter' || event.key === ' ') {
        event.preventDefault();
        selectChoice(li, choice);
      }
    });

    els.choicesList.appendChild(li);
  });

  els.feedbackArea.className = 'feedback-area hidden';
  els.feedbackArea.innerHTML = '';
  els.submitBtn.disabled = true;
  els.submitBtn.classList.remove('hidden');
  els.submitBtn.textContent =
    state.currentQuiz?.mode === 'mock'
      ? state.currentIndex === state.questions.length - 1
        ? 'Submit mock test'
        : 'Save answer'
      : 'Check answer';
  els.nextBtn.classList.add('hidden');
}

function submitAnswer() {
  if (state.answered || !state.selected) return;

  const q = state.questions[state.currentIndex];
  const selected = state.selected;
  const isCorrect = selected === q.answer;

  state.answered = true;
  state.results.push({
    question: q,
    selected,
    correct: isCorrect,
  });

  if (state.currentQuiz?.mode === 'mock') {
    if (state.currentIndex < state.questions.length - 1) {
      state.currentIndex += 1;
      renderQuestion();
    } else {
      renderResults();
    }

    return;
  }

  /** @type {NodeListOf<HTMLLIElement>} */
  const allChoices = document.querySelectorAll('#choices-list .choice-item');

  allChoices.forEach((item) => {
    const value = item.dataset.value || '';
    item.classList.remove('selected');

    if (value === q.answer) {
      item.classList.add('correct');
    }

    if (value === selected && value !== q.answer) {
      item.classList.add('incorrect');
    }

    item.setAttribute('aria-checked', value === selected ? 'true' : 'false');
    item.setAttribute('tabindex', '-1');
  });

  const explanationText = getExplanationText(q, selected, isCorrect);
  const explanationMeta = getExplanationMeta(q, selected, isCorrect);

  els.feedbackArea.className = `feedback-area ${isCorrect ? 'correct' : 'incorrect'}`;
  els.feedbackArea.innerHTML = `
    <div class="feedback-title">${isCorrect ? 'Correct.' : 'Incorrect.'}</div>
    <div class="feedback-answer"><strong>Correct answer:</strong> ${escHtml(q.answer)}</div>
    ${explanationText ? `<div class="feedback-explanation">${escHtml(explanationText)}</div>` : ''}
    ${explanationMeta ? `<div class="feedback-meta">${explanationMeta}</div>` : ''}
  `;

  els.submitBtn.classList.add('hidden');
  els.nextBtn.classList.remove('hidden');
  els.nextBtn.textContent =
    state.currentIndex === state.questions.length - 1 ? 'See results' : 'Next question';
}

/**
 * This is a client-side convenience gate for a static GitHub Pages site.
 * It does not protect the deployed JSON from direct access.
 *
 * @returns {Promise<boolean>}
 */
async function authorizeMockQuiz() {
  try {
    if (sessionStorage.getItem(MOCK_AUTH_SESSION_KEY) === 'true') {
      return true;
    }

    const response = await fetch(MOCK_CONFIG_PATH, { cache: 'no-store' });
    if (!response.ok) {
      throw new Error(`Access configuration request failed (${response.status}).`);
    }

    /** @type {unknown} */
    const payload = await response.json();
    const expectedHash =
      payload && typeof payload === 'object' && 'pretestCPasswordHash' in payload
        ? String(payload.pretestCPasswordHash).toLowerCase()
        : '';

    if (!/^[a-f0-9]{64}$/.test(expectedHash)) {
      throw new Error('The Pretest C access-code hash is not configured.');
    }

    const password = window.prompt('Pretest C password:');
    if (password === null) {
      return false;
    }

    const actualHash = await sha256Hex(password);
    if (actualHash !== expectedHash) {
      window.alert('Incorrect Pretest C password.');
      return false;
    }

    sessionStorage.setItem(MOCK_AUTH_SESSION_KEY, 'true');
    return true;
  } catch (error) {
    const message = error instanceof Error ? error.message : String(error);
    window.alert(`Pretest C could not be unlocked: ${message}`);
    return false;
  }
}

/**
 * @param {string} value
 * @returns {Promise<string>}
 */
async function sha256Hex(value) {
  const bytes = new TextEncoder().encode(value);
  const digest = await crypto.subtle.digest('SHA-256', bytes);

  return Array.from(new Uint8Array(digest), (byte) =>
    byte.toString(16).padStart(2, '0')
  ).join('');
}

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
  els.submitBtn.disabled = false;
}

function nextQuestion() {
  if (!state.answered) return;

  if (state.currentIndex < state.questions.length - 1) {
    state.currentIndex += 1;
    renderQuestion();
    return;
  }

  renderResults();
}

function renderResults() {
  const total = state.results.length;
  const correct = state.results.filter((r) => r.correct).length;
  const percent = total === 0 ? 0 : Math.round((correct / total) * 100);

  els.scoreValue.textContent = `${percent}%`;
  els.scoreDetail.textContent = `${correct} of ${total} correct`;

  els.resultsHeading.textContent =
    percent === 100
      ? 'Perfect score'
      : percent >= 80
        ? 'Strong result'
        : percent >= 60
          ? 'Keep going'
          : 'More review needed';

  if (els.scoreArc) {
    const radius = 52;
    const circumference = 2 * Math.PI * radius;
    const offset = circumference * (1 - percent / 100);
    els.scoreArc.style.strokeDasharray = `${circumference}`;
    els.scoreArc.style.strokeDashoffset = `${offset}`;
  }

  els.resultsList.innerHTML = '';

  state.results.forEach((result, index) => {
    const item = document.createElement('div');
    item.className = `result-item ${result.correct ? 'correct' : 'incorrect'}`;

    item.innerHTML = `
      <div class="result-number">Q${index + 1}</div>
      <div class="result-body">
        <div class="result-question">${escHtml(result.question.question)}</div>
        <div class="result-selected"><strong>Your answer:</strong> ${escHtml(result.selected)}</div>
        <div class="result-correct-answer"><strong>Correct answer:</strong> ${escHtml(result.question.answer)}</div>
        <div class="result-status">${result.correct ? 'Correct' : 'Incorrect'}</div>
      </div>
    `;

    els.resultsList.appendChild(item);
  });

  showView('results');
}

function renderReview() {
  els.reviewList.innerHTML = '';

  state.results.forEach((result, index) => {
    const explanationText = getExplanationText(result.question, result.selected, result.correct);
    const explanationMeta = getExplanationMeta(result.question, result.selected, result.correct);

    const card = document.createElement('div');
    card.className = `review-item ${result.correct ? 'correct' : 'incorrect'}`;

    card.innerHTML = `
      <div class="review-header">
        <div class="review-number">Question ${index + 1}</div>
        <div class="review-status">${result.correct ? 'Correct' : 'Incorrect'}</div>
      </div>
      <div class="review-question">${escHtml(result.question.question)}</div>
      <div class="review-selected"><strong>Your answer:</strong> ${escHtml(result.selected)}</div>
      <div class="review-answer"><strong>Correct answer:</strong> ${escHtml(result.question.answer)}</div>
      ${explanationText ? `<div class="review-explanation">${escHtml(explanationText)}</div>` : ''}
      ${explanationMeta ? `<div class="review-meta">${explanationMeta}</div>` : ''}
    `;

    els.reviewList.appendChild(card);
  });

  showView('review');
}

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
      `<span class="meta-sections"><strong>Sections:</strong> ${escHtml(sections.join(', '))}</span>`
    );
  }

  if (keywords.length) {
    parts.push(
      `<span class="meta-keywords"><strong>Index:</strong> ${escHtml(keywords.join(' | '))}</span>`
    );
  }

  return parts.join(' ');
}

function bindEvents() {
  els.submitBtn?.addEventListener('click', submitAnswer);
  els.nextBtn?.addEventListener('click', nextQuestion);
  els.reviewBtn?.addEventListener('click', renderReview);

  els.retryBtn?.addEventListener('click', () => {
    if (state.currentQuiz) {
      loadQuiz(state.currentQuiz);
    }
  });

  els.backFromReviewBtn?.addEventListener('click', () => {
    showView('results');
  });

  document.querySelectorAll('[data-action="home"]').forEach((btn) => {
    btn.addEventListener('click', () => {
      showView('catalog');
    });
  });
}

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

function initApp() {
  bindEvents();
  renderCatalog();
}

if (document.readyState === 'loading') {
  document.addEventListener('DOMContentLoaded', initApp);
} else {
  initApp();
}
