/*
 * Fills and submits the website login form with stored credentials.
 * The app substitutes the two placeholder arguments on the last line with
 * JSON-encoded username / password strings before evaluating it.
 * Returns: 'submitted' | 'no-form' | 'no-user-field'.
 */
(function (username, password) {
  var passwordInput = document.querySelector('input[type="password"]');
  if (!passwordInput) return 'no-form';
  var form = passwordInput.form || document;
  var userInput = form.querySelector([
    'input[type="email"]',
    'input[autocomplete="username"]',
    'input[name*="user" i]',
    'input[name*="email" i]',
    'input[name*="phone" i]',
    'input[name*="mobile" i]',
    'input[type="tel"]',
    'input[type="text"]'
  ].join(','));
  if (!userInput) return 'no-user-field';

  var setter = Object.getOwnPropertyDescriptor(HTMLInputElement.prototype, 'value').set;
  function setValue(input, value) {
    input.focus();
    setter.call(input, value);
    input.dispatchEvent(new Event('input', { bubbles: true }));
    input.dispatchEvent(new Event('change', { bubbles: true }));
    input.blur();
  }
  setValue(userInput, username);
  setValue(passwordInput, password);

  var remember = form.querySelector('input[type="checkbox"][name*="remember" i]');
  if (remember && !remember.checked) remember.click();

  var submit = form.querySelector('button[type="submit"], input[type="submit"], button:not([type])');
  if (submit) {
    submit.click();
  } else if (form.requestSubmit) {
    form.requestSubmit();
  } else if (form.submit) {
    form.submit();
  }
  return 'submitted';
})(__NEXUS_USERNAME__, __NEXUS_PASSWORD__);
