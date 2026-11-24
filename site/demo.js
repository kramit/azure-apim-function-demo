const element = (id) => document.getElementById(id);
const subscriptionHeader = 'Ocp-Apim-Subscription-Key';

async function runRequest(demo, buttons, buildRequest, display) {
  const status = element(`${demo}-status`);
  const result = element(`${demo}-result`);
  buttons.forEach((button) => { button.disabled = true; });
  status.textContent = 'Sending…';
  result.textContent = '';
  try {
    const url = new URL(element(`${demo}-url`).value);
    if (url.protocol !== 'https:' || url.username || url.password) {
      throw new Error('Enter an HTTPS endpoint without embedded credentials.');
    }
    const response = await fetch(url, {
      ...buildRequest(url),
      redirect: 'error',
      signal: AbortSignal.timeout(45000),
    });
    status.textContent = `HTTP ${response.status}${response.statusText ? ` ${response.statusText}` : ''}`;
    const text = await response.text();
    let body;
    try { body = JSON.parse(text); } catch { body = text; }
    result.textContent = display(response, body);
  } catch (error) {
    status.textContent = 'Request failed';
    result.textContent = error instanceof TypeError
      ? 'Check the endpoint and confirm APIM allows this page’s origin.'
      : error.message;
  } finally {
    buttons.forEach((button) => { button.disabled = false; });
  }
}

function keyFor(demo) {
  const key = element(`${demo}-key`).value.trim();
  if (!key) throw new Error('Enter the subscription key for this API.');
  return key;
}

const pretty = (body) => typeof body === 'string' ? body : JSON.stringify(body, null, 2);
const withoutKey = element('hello-no-key');
const withKey = element('hello-with-key');
for (const button of [withoutKey, withKey]) {
  button.addEventListener('click', () => runRequest('hello', [withoutKey, withKey], (url) => {
    url.searchParams.delete('subscription-key');
    url.searchParams.set('name', 'SC-500');
    return { headers: button === withKey ? { [subscriptionHeader]: keyFor('hello') } : {} };
  }, (_response, body) => pretty(body)));
}

const send = element('agent-send');
send.addEventListener('click', () => {
  element('token-used').textContent = '—';
  element('token-left').textContent = '—';
  return runRequest('agent', [send], () => {
    const input = element('agent-prompt').value.trim();
    if (!input) throw new Error('Enter a prompt.');
    return {
      method: 'POST',
      headers: { 'Content-Type': 'application/json', [subscriptionHeader]: keyFor('agent') },
      body: JSON.stringify({ input }),
    };
  }, (response, body) => {
    element('token-limit').textContent = response.headers.get('X-Token-Rate-Limit') ?? '200';
    element('token-used').textContent = response.headers.get('X-Tokens-Consumed')
      ?? body?.usage?.total_tokens ?? (response.status === 429 ? '0' : '—');
    element('token-left').textContent = response.headers.get('X-Remaining-Tokens') ?? '—';
    const retryAfter = response.headers.get('Retry-After');
    const answer = body?.output?.flatMap((item) => item.content ?? [])
      .filter((part) => part.type === 'output_text').map((part) => part.text).join('\n');
    if (response.status === 429 && retryAfter) {
      return `Retry after ${retryAfter} seconds.\n\n${pretty(body)}`;
    }
    return answer || pretty(body);
  });
});
