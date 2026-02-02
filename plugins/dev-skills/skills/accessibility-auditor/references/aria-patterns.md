# ARIA Best Practices

## ARIA Attributes Reference

### States

| Attribute | Purpose |
|-----------|---------|
| `aria-checked` | Checkbox/radio state |
| `aria-disabled` | Disabled state |
| `aria-expanded` | Expanded/collapsed state |
| `aria-hidden` | Hidden from assistive technology |
| `aria-pressed` | Toggle button state |
| `aria-selected` | Selected state |

### Properties

| Attribute | Purpose |
|-----------|---------|
| `aria-label` | Accessible name |
| `aria-labelledby` | ID reference for label |
| `aria-describedby` | ID reference for description |
| `aria-live` | Live region updates |
| `aria-required` | Required field |
| `aria-invalid` | Validation state |

## Live Regions

```html
<!-- Polite: Wait for pause in speech -->
<div aria-live="polite" aria-atomic="true">
  Item added to cart
</div>

<!-- Assertive: Interrupt immediately -->
<div aria-live="assertive" role="alert">
  Error: Payment failed
</div>

<!-- Status message -->
<div role="status" aria-live="polite">
  Saving changes...
</div>
```

## Custom Components

### Accordion

```html
<div class="accordion">
  <button
    aria-expanded="false"
    aria-controls="panel-1"
    id="accordion-1"
  >
    Section 1
  </button>
  <div id="panel-1" role="region" aria-labelledby="accordion-1" hidden>
    Panel content
  </div>
</div>
```

### Tabs

```html
<div role="tablist" aria-label="Content sections">
  <button
    role="tab"
    aria-selected="true"
    aria-controls="panel-1"
    id="tab-1"
  >
    Tab 1
  </button>
  <button
    role="tab"
    aria-selected="false"
    aria-controls="panel-2"
    id="tab-2"
    tabindex="-1"
  >
    Tab 2
  </button>
</div>

<div role="tabpanel" id="panel-1" aria-labelledby="tab-1">
  Panel 1 content
</div>
<div role="tabpanel" id="panel-2" aria-labelledby="tab-2" hidden>
  Panel 2 content
</div>
```

### Combobox (Autocomplete)

```html
<label for="city-input">City</label>
<div class="combobox-container">
  <input
    type="text"
    id="city-input"
    role="combobox"
    aria-expanded="false"
    aria-autocomplete="list"
    aria-controls="city-listbox"
    aria-activedescendant=""
  >
  <ul
    id="city-listbox"
    role="listbox"
    aria-label="Cities"
    hidden
  >
    <li id="city-1" role="option">New York</li>
    <li id="city-2" role="option">Los Angeles</li>
  </ul>
</div>
```

### Slider

```html
<label id="volume-label">Volume</label>
<div
  role="slider"
  tabindex="0"
  aria-valuemin="0"
  aria-valuemax="100"
  aria-valuenow="50"
  aria-labelledby="volume-label"
>
  <span class="slider-thumb"></span>
</div>
```

### Menu

```html
<button
  aria-haspopup="menu"
  aria-expanded="false"
  aria-controls="actions-menu"
>
  Actions
</button>
<ul
  id="actions-menu"
  role="menu"
  aria-label="Actions"
  hidden
>
  <li role="menuitem" tabindex="-1">Edit</li>
  <li role="menuitem" tabindex="-1">Delete</li>
  <li role="separator"></li>
  <li role="menuitem" tabindex="-1">Share</li>
</ul>
```

## First Rule of ARIA

**No ARIA is better than bad ARIA.**

Prefer native HTML elements over ARIA when possible:

| Instead of ARIA | Use Native HTML |
|-----------------|-----------------|
| `<div role="button">` | `<button>` |
| `<span role="link">` | `<a href="...">` |
| `<div role="checkbox">` | `<input type="checkbox">` |
| `<div role="heading">` | `<h1>` - `<h6>` |
| `<div role="list">` | `<ul>` or `<ol>` |
| `<div role="navigation">` | `<nav>` |
