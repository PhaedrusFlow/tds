/* ── Quiz Catalog ────────────────────────────────────────────────────
   Add entries here when you drop new JSON files into data/.
   Each entry: { id, title, description, file }
──────────────────────────────────────────────────────────────────── */
const quizCatalog = [
  {
    id: 'rcw-19-28',
    title: 'RCW 19.28 — Electrical Installation',
    description: 'Washington State electrical law covering licensing, inspections, and contractor requirements.',
    file: 'data/rcw-19-28.json',
    questionCount: null, // resolved at load
  },
];

/* ── State ──────────────────────────────────────────────────────── */
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

/* ── DOM refs ────────────────────────────────────────────────────── */
const $ = (sel) => document.querySelector(sel);
const views = {
  catalog: $('#view-catalog'),
  quiz:    $('#view-quiz'),
  results: $('#view-results'),
  review:  $('#view-review'),
};

/* ── Theme toggle ────────────────────────────────────────────────── */
(function () {
  const t = $('[data-theme-toggle]');
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
  function updateThemeIcon(btn, theme) {
    btn.setAttribute('aria-label', 'Switch to ' + (theme === 'dark' ? 'light' : 'dark') + ' mode');
    btn.innerHTML = theme === 'dark'
      ? '<svg width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><circle cx="12" cy="12" r="5"/><path d="M12 1v2M12 21v2M4.22 4.22l1.42 1.42M18.36 18.36l1.42 1.42M1 12h2M21 12h2M4.22 19.78l1.42-1.42M18.36 5.64l1.42-1.42"/></svg>'
      : '<svg width="18" height="18" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2"><path d="M21 12.79A9 9 0 1 1 11.21 3 7 7 0 0 0 21 12.79z"/></svg>';
  }
}());

/* ── View management ─────────────────────────────────────────────── */
function showView(name) {
  Object.values(views).forEach(v => v.classList.remove('active'));
  views[name].classList.add('active');
  window.scrollTo({ top: 0, behavior: 'smooth' });
}

/* ── Catalog rendering ───────────────────────────────────────────── */
async function renderCatalog() {
  const grid = $('#quiz-catalog');
  grid.innerHTML = '';

  for (const quiz of quizCatalog) {
    // Fetch question count
    let count = quiz.questionCount;
    if (count === null) {
      try {
        const res = await fetch(quiz.file);
        const data = await res.json();
        quiz.questionCount = data.questions ? data.questions.length : 0;
        count = quiz.questionCount;
      } catch (_) {
        count = '?';
      }
    }

    const card = document.createElement('div');
    card.className = 'catalog-card';
    card.setAttribute('role', 'button');
    card.setAttribute('tabindex', '0');
    card.setAttribute('aria-label', 'Start ' + quiz.title);
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
    const start = () => loadQuiz(quiz);
    card.addEventListener('click', start);
    card.addEventListener('keydown', (e) => { if (e.key === 'Enter' || e.key === ' ') { e.preventDefault(); start(); } });
    grid.appendChild(card);
  }
}

/* ── Load and start quiz ─────────────────────────────────────────── */
async function loadQuiz(quiz) {
  let data;
  try {
    const res = await fetch(quiz.file);
    data = await res.json();
  } catch (err) {
    alert('Could not load quiz file: ' + quiz.file);
    return;
  }

  const shuffleQ = $('#opt-shuffle-q');
  const shuffleC = $('#opt-shuffle-c');

  state.currentQuiz = quiz;
  state.shuffleQ = shuffleQ ? shuffleQ.checked : false;
  state.shuffleC = shuffleC ? shuffleC.checked : false;
  state.questions = data.questions.slice();
  if (state.shuffleQ) shuffle(state.questions);
  state.currentIndex = 0;
  state.results = [];

  $('#quiz-title-display').textContent = quiz.title;
  showView('quiz');
  renderQuestion();
}

/* ── Render question ─────────────────────────────────────────────── */
function renderQuestion() {
  const q = state.questions[state.currentIndex];
  state.selected = null;
  state.answered = false;

  // Progress
  const total = state.questions.length;
  const done  = state.currentIndex;
  $('#progress-label').textContent = `${done + 1} / ${total}`;
  $('#progress-bar').style.width = ((done / total) * 100) + '%';

  // Question text
  $('#question-text').textContent = q.question;

  // Choices
  const choicesList = $('#choices-list');
  choicesList.innerHTML = '';
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
      <span class="choice-letter" aria-hidden="true">${letters[i] || i + 1}</span>
      <span class="choice-text">${escHtml(choice)}</span>
    `;
    li.addEventListener('click', () => selectChoice(li, choice, choices));
    li.addEventListener('keydown', (e) => {
      if (e.key === 'Enter' || e.key === ' ') { e.preventDefault(); selectChoice(li, choice, choices); }
    });
    choicesList.appendChild(li);
  });

  // Reset feedback/buttons
  const feedback = $('#feedback-area');
  feedback.className = 'feedback-area hidden';
  feedback.innerHTML = '';
  const submitBtn = $('#btn-submit');
  const nextBtn = $('#btn-next');
  submitBtn.disabled = true;
  submitBtn.classList.remove('hidden');
  nextBtn.classList.add('hidden');
}

/* ── Select choice ───────────────────────────────────────────────── */
function selectChoice(el, value, choices) {
  if (state.answered) return;
  state.selected = value;
  document.querySelectorAll('.choice-item').forEach(c => {
    c.classList.remove('selected');
    c.setAttribute('aria-checked', 'false');
  });
  el.classList.add('selected');
  el.setAttribute('aria-checked', 'true');
  $('#btn-submit').disabled = false;
}

/* ── Submit answer ───────────────────────────────────────────────── */
$('#btn-submit').addEventListener('click', () => {
  if (!state.selected || state.answered) return;
  state.answered = true;

  const q = state.questions[state.currentIndex];
  const correct = state.selected === q.answer;
  state.results.push({ question: q, selected: state.selected, correct });

  // Mark choices
  document.querySelectorAll('.choice-item').forEach(item => {
    item.classList.add('disabled');
    item.setAttribute('tabindex', '-1');
    if (item.dataset.value === q.answer) item.classList.add('correct');
    else if (item.dataset.value === state.selected && !correct) item.classList.add('wrong');
    item.classList.remove('selected');
  });

  // Feedback
  const feedback = $('#feedback-area');
  feedback.className = 'feedback-area ' + (correct ? 'correct-fb' : 'wrong-fb');
  if (correct) {
    feedback.innerHTML = '<strong class="feedback-strong">Correct!</strong>' +
      (q.explanation ? escHtml(q.explanation) : '');
  } else {
    feedback.innerHTML = '<strong class="feedback-strong">Incorrect.</strong>' +
      'Correct answer: <strong>' + escHtml(q.answer) + '</strong>' +
      (q.explanation ? '<br>' + escHtml(q.explanation) : '');
  }

  $('#btn-submit').classList.add('hidden');
  $('#btn-next').classList.remove('hidden');
});

/* ── Next question ───────────────────────────────────────────────── */
$('#btn-next').addEventListener('click', () => {
  state.currentIndex++;
  if (state.currentIndex >= state.questions.length) {
    showResults();
  } else {
    renderQuestion();
  }
});

/* ── Back buttons ────────────────────────────────────────────────── */
$('#btn-back-to-catalog').addEventListener('click', () => showView('catalog'));
$('#btn-back-from-results').addEventListener('click', () => showView('catalog'));
$('#btn-back-from-review').addEventListener('click', () => showView('results'));

/* ── Results ─────────────────────────────────────────────────────── */
function showResults() {
  const total   = state.results.length;
  const correct = state.results.filter(r => r.correct).length;
  const pct     = Math.round((correct / total) * 100);

  // Animate score ring
  const circumference = 326.7;
  const offset = circumference - (pct / 100) * circumference;
  setTimeout(() => {
    $('#score-arc').style.strokeDashoffset = offset;
  }, 100);

  // Color ring by score
  const arc = $('#score-arc');
  if (pct >= 80) arc.style.stroke = 'var(--color-correct)';
  else if (pct >= 60) arc.style.stroke = 'var(--color-primary)';
  else arc.style.stroke = 'var(--color-wrong)';

  $('#score-pct').textContent = pct + '%';

  const heading = pct >= 90 ? 'Outstanding work.'
    : pct >= 80 ? 'Well done!'
    : pct >= 70 ? 'Good progress.'
    : pct >= 60 ? 'Keep studying.'
    : 'More review needed.';
  $('#results-heading').textContent = heading;
  $('#results-sub').textContent = `${correct} of ${total} correct. Verify answers against current RCW text before relying on results for exam prep.`;

  showView('results');
}

/* ── Retake ──────────────────────────────────────────────────────── */
$('#btn-retake').addEventListener('click', () => loadQuiz(state.currentQuiz));

/* ── Review ──────────────────────────────────────────────────────── */
$('#btn-review').addEventListener('click', () => {
  const list = $('#review-list');
  list.innerHTML = '';
  state.results.forEach((r, i) => {
    const div = document.createElement('div');
    div.className = 'review-item ' + (r.correct ? 'r-correct' : 'r-wrong');
    const choicesHtml = r.question.choices.map(c => {
      const isCorrect = c === r.question.answer;
      const isSelected = c === r.selected;
      if (!isCorrect && !isSelected) return '';
      const cls = isCorrect ? 'ra-correct' : 'ra-wrong';
      const badge = isCorrect
        ? '<span class="badge badge-correct">Correct answer</span>'
        : '<span class="badge badge-wrong">Your answer</span>';
      return `<div class="review-answer ${cls}">${badge} <span>${escHtml(c)}</span></div>`;
    }).join('');

    div.innerHTML = `
      <div class="review-q-num">Question ${i + 1}</div>
      <p class="review-q-text">${escHtml(r.question.question)}</p>
      <div class="review-answers">${choicesHtml}</div>
      ${r.question.explanation ? '<p class="review-explanation">' + escHtml(r.question.explanation) + '</p>' : ''}
    `;
    list.appendChild(div);
  });
  showView('review');
});

/* ── Utilities ───────────────────────────────────────────────────── */
function shuffle(arr) {
  for (let i = arr.length - 1; i > 0; i--) {
    const j = Math.floor(Math.random() * (i + 1));
    [arr[i], arr[j]] = [arr[j], arr[i]];
  }
  return arr;
}
function escHtml(str) {
  return String(str)
    .replace(/&/g, '&amp;').replace(/</g, '&lt;')
    .replace(/>/g, '&gt;').replace(/"/g, '&quot;');
}

/* ── Init ────────────────────────────────────────────────────────── */
renderCatalog();
