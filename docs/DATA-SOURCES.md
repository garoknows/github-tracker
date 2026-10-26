# Data sources

Tracker for GitHub reads only public data from GitHub. This page records exactly what it calls, what was verified, and how it degrades when something changes. Everything was checked live on **October 26, 2026** without logging in.

| What | Where it comes from | Login? | Code |
|---|---|---|---|
| Daily contributions (the graph) | `https://github.com/users/{name}/contributions` (HTML) | No | `CalendarParser` |
| Activity overview percentages (the quadrant) | `https://github.com/{name}?action=show&controller=profiles&tab=contributions&user_id={name}` (HTML fragment) | No | `OverviewParser` |
| Name and avatar | `https://api.github.com/users/{name}` (REST, cached 24 h) | No | `GitHubClient.profile` |
| Fallback for both of the above | `https://api.github.com/graphql` | Token | `GitHubClient.graphQL` |

Every request sends `User-Agent: TrackerForGitHub/1.0 (+https://github.com/garoknows/github-tracker)`. The client refuses any host other than `github.com` and `api.github.com`. Avatar images are shown from GitHub's image host (`avatars.githubusercontent.com`), the same place github.com loads them from.

## 1. Contribution calendar

`GET https://github.com/users/{name}/contributions` returns an HTML fragment (about 230 KB) with:

- one `<td class="ContributionCalendar-day">` per day, carrying `data-date="2026-10-21"`, `data-level="0…4"` and an `id` like `contribution-day-component-3-51`;
- a matching `<tool-tip for="contribution-day-component-3-51">` whose text holds the count: `No contributions on October 26th.`, `1 contribution on April 2nd.`, `21 contributions on October 21st.` (thousands use commas: `1,234`);
- the total in `<h2 id="js-contribution-activity-description">`: `93 contributions in the last year`.

It covers 366 or 367 days, starting on a Sunday about a year ago, so the graph always has 53 columns. A user that doesn't exist returns **HTTP 404** with the body `Not Found`.

The parser doesn't depend on attribute order. The intensity level comes from GitHub's own `data-level`, so the colors match github.com exactly.

## 2. Activity overview (verified: public, no login)

**Finding: the public profile does expose the percentages without logging in.** The profile page loads its contributions section lazily from:

```
https://github.com/{name}?action=show&controller=profiles&tab=contributions&user_id={name}
```

When requested with the header `X-Requested-With: XMLHttpRequest`, the fragment contains:

```html
<div class="… js-activity-overview-graph-container"
     data-percentages="{&quot;Commits&quot;:53,&quot;Issues&quot;:40,&quot;Pull requests&quot;:7,&quot;Code review&quot;:0}">
```

Without that header GitHub returns a variant without `data-percentages`.

What the fragment looks like in each case:

| Case | What the fragment contains | App shows |
|---|---|---|
| Owner has Activity overview **on** | `activity-overview-box` and `data-percentages` | The quadrant chart |
| Owner turned it **off** | `graph-before-activity-overview` but no `activity-overview-box` | "Activity overview is turned off on this profile." |
| Anything unexpected (layout change, login wall) | Neither | "Add a free token in Settings to show this chart." |

Saved, trimmed fixtures for all three cases live in `Packages/TrackerKit/Tests/TrackerKitTests/Fixtures/`.

## 3. GraphQL fallback (needs a token)

With a token (which needs no scopes), the app can ask GraphQL for:

```graphql
user(login: $login) {
  contributionsCollection {
    totalCommitContributions totalIssueContributions
    totalPullRequestContributions totalPullRequestReviewContributions
    contributionCalendar { totalContributions weeks { contributionDays { date contributionCount contributionLevel } } }
  }
}
```

It's used:

- for the **quadrant**, when the public fragment doesn't have it. The four totals become whole-number percentages that add up to 100 (largest-remainder rounding).
- for the **calendar**, when the HTML can't be parsed (for example, GitHub redesigned it).

**Known difference:** GraphQL totals count only *public* contributions for other people, while GitHub's own chart also weighs private ones when the owner shares them. For one test profile the public page showed 53% commits / 40% issues / 7% PRs, while GraphQL returned 2 public commits plus 89 restricted contributions. So the app always prefers the public numbers and labels GraphQL-based charts as "computed from GitHub's API with your token."

Verification was done with `gh api graphql` on the developer's machine only. No token is in the code, fixtures or tests.

## 4. Limits and politeness

- **Profiles (REST):** 60 requests/hour without a token. Name and avatar are cached for 24 hours.
- **HTML pages:** fetched once per favorite per refresh (default every 30 minutes), one favorite at a time with a short pause.
- **Rate limits:** on `429`, or `403` with `x-ratelimit-remaining: 0`, the client stops calling that host until `Retry-After` / `x-ratelimit-reset`, or backs off 1 → 2 → 4 … 60 minutes. While paused it sends nothing.
- **Offline:** the last good data per profile is cached on disk and shown with "Offline, showing data from 2 hr ago."

## 5. If GitHub changes something

1. Save fresh HTML into the fixtures folder.
2. Run `swift test --package-path Packages/TrackerKit`. The parser tests show what broke.
3. Fix `CalendarParser` or `OverviewParser`; nothing else reads GitHub's markup.

Users with a token keep working through GraphQL in the meantime.
