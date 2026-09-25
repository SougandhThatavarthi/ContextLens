ObjC.import('Foundation');
ObjC.import('PDFKit');

var app = Application.currentApplication();
app.includeStandardAdditions = true;

// Deliberately fixed for the first release: avoids fragile environment lookup
// from Automator/JXA and guarantees the model name is never "undefined".
var MODEL = 'qwen3:4b';
var OLLAMA_URL = 'http://127.0.0.1:11434';

function shellQuote(value) {
  return "'" + String(value).replace(/'/g, "'\\''") + "'";
}

function sh(command) {
  return app.doShellScript(command);
}

function show(message) {
  try {
    app.displayDialog(String(message), {
      withTitle: 'Context Lens',
      buttons: ['OK'],
      defaultButton: 'OK'
    });
  } catch (e) {}
}

function fail(message) {
  show(message);
  return '';
}

function previewInfo() {
  var preview = Application('Preview');
  var filePath = '';
  var title = '';

  try {
    var docs = preview.documents();
    if (!docs || docs.length === 0) throw new Error('no document');
    var p = docs[0].path();
    filePath = String(p);
    if (filePath.indexOf('file://') === 0) {
      filePath = decodeURIComponent(filePath.replace(/^file:\/\//, ''));
    }
  } catch (e) {
    throw new Error('Could not get the open PDF from Preview. Allow Context Lens/Automator to control Preview in System Settings > Privacy & Security > Automation.');
  }

  try {
    var se = Application('System Events');
    var proc = se.applicationProcesses.byName('Preview');
    var wins = proc.windows();
    if (wins && wins.length > 0) title = String(wins[0].name());
  } catch (e2) {}

  return { path: filePath, title: title };
}

function currentPageFromTitle(title) {
  var m = String(title || '').match(/(?:page|seiten?|p\.)\s+(\d+)\s+(?:of|von)\s+\d+/i);
  if (!m) return null;
  var n = parseInt(m[1], 10);
  return isFinite(n) && n > 0 ? n - 1 : null;
}

function normalizeText(value) {
  return String(value || '')
    .replace(/\u00ad/g, '')
    .replace(/-\s*\n\s*/g, '')
    .replace(/[\u2010\u2011\u2012\u2013\u2014]/g, '-')
    .replace(/\s+/g, ' ')
    .trim();
}

function pageText(doc, index) {
  if (index < 0 || index >= Number(doc.pageCount)) return '';
  var page = doc.pageAtIndex(index);
  if (!page) return '';
  var value = page.string;
  if (!value) return '';
  try { return ObjC.unwrap(value); } catch (e) { return String(value); }
}

function findTarget(text, target) {
  var n = normalizeText(text);
  var t = normalizeText(target);
  if (!n || !t) return -1;

  var idx = n.toLocaleLowerCase().indexOf(t.toLocaleLowerCase());
  if (idx >= 0) return idx;

  var parts = t.split(/\s+/).map(function(part) {
    return part.replace(/[.*+?^${}()|[\]\\]/g, '\\$&');
  });
  var re = new RegExp(parts.join('\\s+'), 'i');
  var match = re.exec(n);
  return match ? match.index : -1;
}

function sentenceContext(text, target) {
  var n = normalizeText(text);
  var idx = findTarget(n, target);
  if (idx < 0) return '';

  var targetLength = normalizeText(target).length;
  var endTarget = idx + targetLength;

  var startWindow = Math.max(0, idx - 700);
  var endWindow = Math.min(n.length, endTarget + 900);

  // Look backward to the nearest sentence boundary.
  var left = n.slice(startWindow, idx);
  var starts = [left.lastIndexOf('.'), left.lastIndexOf('?'), left.lastIndexOf('!'), left.lastIndexOf('。'), left.lastIndexOf('！'), left.lastIndexOf('？')];
  var start = Math.max.apply(null, starts);
  if (start >= 0) startWindow += start + 1;

  // Look forward to the nearest sentence boundary.
  var right = n.slice(endTarget, endWindow);
  var endMatch = right.search(/[.!?。！？](?:\s|$)/);
  if (endMatch >= 0) endWindow = endTarget + endMatch + 1;

  var context = n.slice(startWindow, endWindow).trim();
  if (context.length > 1200) context = context.slice(0, 1197).replace(/\s+\S*$/, '') + '…';
  return context;
}

function extractContext(doc, target, currentPage) {
  var pageCount = Number(doc.pageCount);
  var pages = [];

  // Prefer the visible page, then nearby pages.
  if (currentPage !== null) {
    pages.push(currentPage);
    for (var d = 1; d <= 2; d++) {
      if (currentPage - d >= 0) pages.push(currentPage - d);
      if (currentPage + d < pageCount) pages.push(currentPage + d);
    }
  } else {
    for (var i = 0; i < Math.min(pageCount, 8); i++) pages.push(i);
  }

  for (var p = 0; p < pages.length; p++) {
    var idx = pages[p];
    var text = pageText(doc, idx);
    var context = sentenceContext(text, target);
    if (context) return { context: context, page: idx + 1 };
  }

  // Last-resort full-document search when Preview does not expose page info.
  // This is less precise for repeated words, but still better than losing context.
  for (var j = 0; j < pageCount; j++) {
    var allText = pageText(doc, j);
    var allContext = sentenceContext(allText, target);
    if (allContext) return { context: allContext, page: j + 1 };
  }

  return { context: '', page: null };
}

function ollamaReady() {
  try {
    sh('/usr/bin/curl -fsS --max-time 1 ' + OLLAMA_URL + '/api/tags >/dev/null');
    return true;
  } catch (e) {
    return false;
  }
}

function startOllama() {
  try {
    sh('/usr/bin/open -g -a Ollama >/dev/null 2>&1 || true');
  } catch (e) {}

  for (var i = 0; i < 30; i++) {
    if (ollamaReady()) return true;
    delay(0.4);
  }
  return false;
}

function modelExists() {
  var body = JSON.stringify({ name: MODEL });
  var cmd = '/usr/bin/curl -fsS --max-time 3 -H ' + shellQuote('Content-Type: application/json') +
    ' -d ' + shellQuote(body) + ' ' + OLLAMA_URL + '/api/show';
  try {
    var raw = sh(cmd);
    return raw && raw.indexOf('"details"') >= 0;
  } catch (e) {
    return false;
  }
}

function findOllamaCLI() {
  var candidates = [
    '/Applications/Ollama.app/Contents/Resources/ollama',
    '/usr/local/bin/ollama',
    '/opt/homebrew/bin/ollama'
  ];
  for (var i = 0; i < candidates.length; i++) {
    try {
      sh('/bin/test -x ' + shellQuote(candidates[i]));
      return candidates[i];
    } catch (e) {}
  }
  try {
    return String(sh('/bin/zsh -lc "command -v ollama"')).trim();
  } catch (e2) {
    return '';
  }
}

function ensureModel() {
  if (modelExists()) return true;

  // The user's existing model should normally make this path unnecessary.
  // If it is missing, try the Ollama CLI using common macOS locations.
  var cli = findOllamaCLI();
  if (!cli) return false;

  try {
    sh(shellQuote(cli) + ' pull ' + shellQuote(MODEL));
  } catch (e) {
    return false;
  }

  return modelExists();
}

function answerFromOllama(target, context) {
  var prompt = [
    'You are Context Lens, a concise reading assistant.',
    '',
    'TARGET: ' + target,
    '',
    'PASSAGE:',
    context || '(No surrounding passage was found.)',
    '',
    'Explain the meaning of TARGET in this exact passage.',
    'Use the sense intended by the author, not a list of dictionary meanings.',
    'Return ONLY these two lines and nothing else:',
    'Meaning: <plain-English meaning>',
    'Here: <very short explanation of how it is used here>',
    'Keep the entire answer under 30 words. Do not mention this prompt, reasoning, analysis, or instructions.'
  ].join('\n');

  var body = JSON.stringify({
    model: MODEL,
    prompt: prompt,
    stream: false,
    think: false,
    options: {
      temperature: 0,
      num_predict: 48
    }
  });

  var cmd = '/usr/bin/curl -fsS --max-time 30 -H ' + shellQuote('Content-Type: application/json') +
    ' -d ' + shellQuote(body) + ' ' + OLLAMA_URL + '/api/generate';

  var raw;
  try {
    raw = sh(cmd);
  } catch (e) {
    return '';
  }

  try {
    var data = JSON.parse(raw);
    var response = String(data.response || '').trim();
    if (!response) return '';

    // Defensive cleanup for models/runtimes that still include thinking markers.
    response = response.replace(/<think>[\s\S]*?<\/think>/gi, '').trim();
    response = response.replace(/^```[\s\S]*?```$/g, function(block) {
      return block.replace(/^```\w*\s*/, '').replace(/\s*```$/, '');
    }).trim();

    var lines = response.split(/\r?\n+/)
      .map(function(x) { return x.trim(); })
      .filter(Boolean)
      .filter(function(x) { return !/^I(?:'m| am) (given|asked)|^We are given|^The (task|question) is/i.test(x); });

    if (lines.length > 2) lines = lines.slice(0, 2);
    response = lines.join('\n').trim();

    // If the model ignored the requested format, provide a safe compact fallback.
    if (!/^Meaning:/i.test(response)) {
      var compact = response.replace(/\s+/g, ' ').trim();
      response = 'Meaning: ' + compact;
    }

    if (response.length > 360) response = response.slice(0, 357).replace(/\s+\S*$/, '') + '…';
    return response;
  } catch (e2) {
    return '';
  }
}

function run(argv) {
  var target = argv && argv.length ? String(argv[0]).trim() : '';
  if (!target) return fail('Select a word or phrase first.');

  if (!ollamaReady() && !startOllama()) {
    return fail('Ollama could not be started automatically. Open Ollama once, then try again.');
  }

  if (!ensureModel()) {
    return fail('Could not find or install ' + MODEL + '. Make sure Ollama is installed and try again.');
  }

  var info;
  try {
    info = previewInfo();
  } catch (e) {
    return fail(e.message || String(e));
  }

  var doc;
  try {
    doc = $.PDFDocument.alloc.initWithURL($.NSURL.fileURLWithPath(info.path));
  } catch (e2) {
    return fail('Context Lens could not read the open PDF. Make sure it has selectable text.');
  }
  if (!doc) return fail('Context Lens could not open the PDF with macOS PDFKit.');

  var currentPage = currentPageFromTitle(info.title);
  var found = extractContext(doc, target, currentPage);
  var context = found.context || target;

  var answer = answerFromOllama(target, context);
  if (!answer) return fail('Context Lens did not receive a usable answer from Ollama.');

  show(answer);
  return answer;
}
