# Resticprofile Module

> Sample markdown for testing markdown editor extension.

## Overview

This module configures **resticprofile** for backup management with **restic**.

### Features

- Local and B2 (Backblaze) repositories
- Development and home backup profiles
- `Retenti`

## Headings

### H3 Heading

#### H4 Heading

##### H5 Heading

###### H6 Heading

## Text Formatting

**Bold text** and _italic text_ and **_bold italic_**.

~~Strikethrough~~ and `inline code`.

## Lists

### Unordered

- Item one
- Item two
  - Nested item
  - Another nested
- Item three

### Ordered

1. First
2. Second
3. Third

### Task list

- [X] Completed task
- [ ] Pending task
- [ ] Another pending

## Code Blocks

```bash
resticprofile backup development-local-fast
```

```yaml
profiles:
  base:
    initialize: true
    password-file: "{{ .Env.HOME }}/.config/resticprofile/development.key"
```

## Links and Images

[Link to restic](https://restic.net/) and [relative link](./config/profiles.yaml).

![Alt text](https://via.placeholder.com/150 "Optional title")

## Table


| Profile                | Repo  | Schedule |
| ------------------------ | ------- | ---------- |
| development-local-fast | local | 30 min   |
| home-local             | local | daily    |
| development-b2         | B2    | weekly   |
| home-b2                | B2    | weekly   |

## Blockquote

> This is a blockquote.
>
> It can span multiple paragraphs.

## Horizontal Rule

---

## Math (if supported)

Inline: $E = mc^2$

Block:

$$
\int_{-\infty}^{\infty} e^{-x^2} dx = \sqrt{\pi}

$$

## Footnotes

Here is a footnote reference[^1].

[^1]: This is the footnote content.
