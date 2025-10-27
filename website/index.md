---
layout: default
title: BearMinder — Bear → Beeminder
---

<section class="hero">
  <div class="container">
    <div class="hero-grid">
      <div class="hero-copy">
        <h1>Effortless word-count syncing from Bear to Beeminder</h1>
        <p class="lead">A tiny macOS menu bar app that tracks your daily writing in Bear and updates your Beeminder goal automatically. No manual entry. No workflow changes. Just write.</p>
        <div class="actions">
          <a class="btn primary" href="https://github.com/brennanbrown/bearminder">View on GitHub</a>
          <a class="btn" href="#setup">How it works</a>
        </div>
        <ul class="ticks">
          <li>Runs in the background, syncs hourly</li>
          <li>On‑demand “Sync now” from the menu bar</li>
          <li>Private by design — only word counts leave your Mac</li>
        </ul>
      </div>
      <div class="hero-media">
        <img src="/assets/images/screenshot.png" alt="BearMinder menu bar and settings screenshot">
      </div>
    </div>
  </div>
</section>

<section id="features" class="section">
  <div class="container">
    <h2>Why use BearMinder?</h2>
    <div class="features">
      <div class="feature">
        <h3>Zero‑friction writing</h3>
        <p>Keep using Bear exactly as you do today. BearMinder quietly totals your daily words and keeps Beeminder up to date.</p>
      </div>
      <div class="feature">
        <h3>Rich Beeminder datapoints</h3>
        <p>Posts cumulative daily word counts with helpful context like notes touched, tags, and timing windows.</p>
      </div>
      <div class="feature">
        <h3>Reliable and lightweight</h3>
        <p>Native macOS app using minimal CPU and memory. Stores tokens in Keychain and handles offline retries.</p>
      </div>
    </div>
  </div>
</section>

<section id="setup" class="section alt">
  <div class="container">
    <h2>Quick setup (2 minutes)</h2>
    <ol class="steps">
      <li>Open Bear → Help → Advanced → copy your API token.</li>
      <li>Create a Beeminder account, make a <code>writing</code> goal, and get your auth token.</li>
      <li>Launch BearMinder and paste tokens, username, and goal name. Choose tags (optional) and save.</li>
    </ol>
    <p class="note">After that, BearMinder syncs every hour automatically. You can also click the 🐻 icon and choose <em>Sync Now</em>.</p>
  </div>
</section>
