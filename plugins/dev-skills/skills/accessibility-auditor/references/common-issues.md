# Common Accessibility Issues & Fixes

## 1. Missing Alt Text for Images

**Problem:**
```html
<img src="/products/shoes.jpg">
```

**Solution:**
```html
<!-- Informative image -->
<img src="/products/shoes.jpg" alt="Red Nike Air Max running shoes with white swoosh">

<!-- Decorative image -->
<img src="/decorative-pattern.svg" alt="" role="presentation">

<!-- Logo that links -->
<a href="/">
  <img src="/logo.png" alt="Company Name - Home">
</a>
```

**Rules:**
- Informative images: Describe the content/function
- Decorative images: Use empty alt (alt="")
- Functional images: Describe the action
- Complex images: Provide detailed description nearby

## 2. Low Color Contrast

**Problem:**
```css
/* Contrast ratio 2.5:1 - Fails WCAG */
.text {
  color: #767676;
  background: #ffffff;
}
```

**Solution:**
```css
/* Contrast ratio 4.5:1+ - Passes AA */
.text {
  color: #595959;
  background: #ffffff;
}

/* Contrast ratio 7:1+ - Passes AAA */
.text-high-contrast {
  color: #333333;
  background: #ffffff;
}
```

**Requirements:**
- Normal text (< 18px): 4.5:1 minimum (AA), 7:1 enhanced (AAA)
- Large text (>= 18px or >= 14px bold): 3:1 minimum (AA), 4.5:1 enhanced (AAA)
- UI components and graphics: 3:1 minimum

## 3. Non-Semantic HTML

**Problem:**
```html
<div class="button" onclick="submitForm()">Submit</div>
<div class="heading">Page Title</div>
<div class="nav-menu">...</div>
```

**Solution:**
```html
<button type="submit" onclick="submitForm()">Submit</button>
<h1>Page Title</h1>
<nav aria-label="Main navigation">...</nav>
```

**Semantic Elements:**
- `<button>` for buttons
- `<a>` for links
- `<h1>` - `<h6>` for headings (hierarchical)
- `<nav>`, `<main>`, `<aside>`, `<article>`, `<section>` for landmarks
- `<ul>`, `<ol>`, `<li>` for lists
- `<table>`, `<th>`, `<td>` for tabular data

## 4. Missing Form Labels

**Problem:**
```html
<input type="email" placeholder="Enter your email">
```

**Solution:**
```html
<!-- Explicit label -->
<label for="email">Email Address</label>
<input type="email" id="email" name="email">

<!-- Implicit label -->
<label>
  Email Address
  <input type="email" name="email">
</label>

<!-- Hidden label (for tight layouts) -->
<label for="search" class="sr-only">Search</label>
<input type="text" id="search" placeholder="Search...">
```

**Best Practices:**
- Every form field must have an associated label
- Labels should be visible (don't rely on placeholder)
- Use aria-label only when visual label isn't possible
- Group related fields with `<fieldset>` and `<legend>`

## 5. Keyboard Navigation Issues

**Problem:**
```html
<div onclick="handleClick()">Click me</div>
<a href="javascript:void(0)" onclick="doSomething()">Action</a>
```

**Solution:**
```html
<!-- Use proper button -->
<button onclick="handleClick()">Click me</button>

<!-- If div required, make it accessible -->
<div
  role="button"
  tabindex="0"
  onclick="handleClick()"
  onkeydown="handleKeyPress(event)"
>
  Click me
</div>

<script>
function handleKeyPress(event) {
  if (event.key === 'Enter' || event.key === ' ') {
    event.preventDefault();
    handleClick();
  }
}
</script>
```

**Keyboard Requirements:**
- All interactive elements must be keyboard accessible
- Visible focus indicators (outline or custom styling)
- Logical tab order (matches visual flow)
- Skip links for repetitive content
- No keyboard traps (users can navigate away)

## 6. Missing ARIA Landmarks

**Problem:**
```html
<div class="header">...</div>
<div class="main-content">...</div>
<div class="sidebar">...</div>
<div class="footer">...</div>
```

**Solution:**
```html
<header role="banner">
  <nav aria-label="Main navigation">...</nav>
</header>

<main role="main">
  <h1>Page Title</h1>
  <article>...</article>
</main>

<aside role="complementary" aria-label="Related articles">
  ...
</aside>

<footer role="contentinfo">
  ...
</footer>
```

**Common Landmarks:**
- `banner` - Site header
- `navigation` - Navigation menus
- `main` - Primary content (one per page)
- `complementary` - Supporting content
- `contentinfo` - Site footer
- `search` - Search functionality
- `form` - Form regions

## 7. Inaccessible Modals/Dialogs

**Problem:**
```html
<div class="modal">
  <div class="content">
    Modal content
    <button onclick="closeModal()">Close</button>
  </div>
</div>
```

**Solution:**
```html
<div
  role="dialog"
  aria-modal="true"
  aria-labelledby="modal-title"
  aria-describedby="modal-desc"
>
  <h2 id="modal-title">Confirm Action</h2>
  <p id="modal-desc">Are you sure you want to delete this item?</p>

  <button onclick="confirmAction()">Confirm</button>
  <button onclick="closeModal()">Cancel</button>
</div>

<script>
// Focus management
function openModal() {
  const modal = document.querySelector('[role="dialog"]');
  const focusableElements = modal.querySelectorAll(
    'button, [href], input, select, textarea, [tabindex]:not([tabindex="-1"])'
  );

  // Store previous focus
  previousFocus = document.activeElement;

  // Focus first element
  focusableElements[0].focus();

  // Trap focus
  modal.addEventListener('keydown', trapFocus);
}

function closeModal() {
  // Return focus
  if (previousFocus) previousFocus.focus();
}

function trapFocus(event) {
  if (event.key !== 'Tab') return;

  const focusableElements = Array.from(
    modal.querySelectorAll('button, [href], input, select, textarea, [tabindex]:not([tabindex="-1"])')
  );

  const firstElement = focusableElements[0];
  const lastElement = focusableElements[focusableElements.length - 1];

  if (event.shiftKey && document.activeElement === firstElement) {
    lastElement.focus();
    event.preventDefault();
  } else if (!event.shiftKey && document.activeElement === lastElement) {
    firstElement.focus();
    event.preventDefault();
  }
}
</script>
```

**Modal Requirements:**
- `role="dialog"` or `role="alertdialog"`
- `aria-modal="true"` to indicate modal behavior
- `aria-labelledby` pointing to title
- `aria-describedby` for description (optional)
- Focus management (trap and restore)
- Close on Escape key
- Prevent background scrolling

## 8. Missing Skip Links

**Solution:**
```html
<a href="#main-content" class="skip-link">
  Skip to main content
</a>

<header>
  <nav>...</nav>
</header>

<main id="main-content" tabindex="-1">
  <!-- Page content -->
</main>

<style>
.skip-link {
  position: absolute;
  top: -40px;
  left: 0;
  background: #000;
  color: #fff;
  padding: 8px;
  text-decoration: none;
  z-index: 100;
}

.skip-link:focus {
  top: 0;
}
</style>
```
