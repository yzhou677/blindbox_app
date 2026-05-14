# Blind Box Collection App

## Project Goal

Build a modern Flutter mobile app for designer toy and blind box collectors.

The app should feel premium, minimal, visual-first, and collection-focused.

Inspired by:
- POP MART
- Collectr
- StockX
- Pinterest
- modern iOS collectible apps

The goal is NOT to build a social media platform.

The goal is to help users:
- track collections
- discover latest drops
- organize collectibles
- monitor market trends

---

# Core Features

## 1. Latest Drops Feed

A visual feed showing newly released collectibles.

Each item includes:
- image
- name
- series
- brand
- release date

UI style:
- large image cards
- rounded corners
- soft shadows
- modern minimal spacing
- horizontal scrolling sections

This data can initially come from:
- local mock JSON
- Firebase later

No complex backend required for MVP.

---

## 2. Market Section

Display market information using eBay APIs.

Features:
- search collectibles
- current market listings
- average prices
- trending collectibles

This section should feel lightweight and fast.

Not intended to be a full marketplace.

---

## 3. My Collection

Local-first collection tracking.

No login required for MVP.

Users can:
- add collectibles
- track quantities
- save purchase price
- mark owned items
- add notes

Local storage options:
- Hive
or
- Isar

Collection view should feel like:
- Pinterest
- collectible shelf
- visual gallery

NOT spreadsheet-like.

---

# Design Philosophy

The app should feel:
- cozy
- modern
- visual
- collectible-focused
- emotionally pleasing

Avoid:
- enterprise dashboard style
- cyberpunk UI
- overly technical design
- cluttered screens

Prioritize:
- whitespace
- typography
- large images
- smooth animations
- polished loading states

---

# Navigation

Use Bottom Navigation with 3 tabs:

1. Home
2. Market
3. Collection

---

# Tech Stack

## Framework
Flutter

## State Management
Riverpod

## Routing
go_router

## Local Storage
Hive or Isar

## Networking
Dio

## Image Caching
cached_network_image

---

# Architecture

Use clean folder structure:

lib/
  core/
  features/
  shared/
  services/
  models/

Use:
- repository pattern
- async state handling
- feature-based structure

Avoid:
- massive widget files
- business logic inside UI
- global mutable state

---

# UI Direction

Inspired by:
- Apple Today cards
- Pinterest grids
- Collectr app
- StockX modern cards

Cards should:
- use large collectible images
- have rounded corners
- feel premium but playful

Animations:
- hero transitions
- smooth page transitions
- shimmer loading states

---

# MVP Scope

DO NOT overbuild.

MVP should only include:
- latest releases
- market listings
- local collection tracking

No:
- social features
- chat
- comments
- authentication
- cloud sync
- payments

---

# User Pain Points (Research)

Users currently complain about:
- outdated collectible databases
- missing new series
- inability to create custom lists
- using spreadsheets instead of apps
- poor collection organization

The app should prioritize:
- easy browsing
- fast updates
- visual organization
- collectible completeness

---

# Product Personality

The app should feel like:
"A beautiful digital shelf for collectors."

# Development Priority

Prioritize shipping a polished MVP quickly.

Prefer:
- simpler implementations
- clean UI
- maintainable code
- fast iteration

Avoid premature optimization and unnecessary abstractions.

# Theme

Support both light mode and dark mode.

Default design direction should prioritize:
- warm neutral backgrounds
- soft shadows
- collectible-focused visuals

Avoid overly saturated colors.

# Visual Priority

Collectible images are the most important UI element.

Layouts should prioritize:
- large imagery
- clean presentation
- consistent aspect ratios
- smooth image loading

Text should support the visuals, not dominate the screen.

## Current Backend Status

The app currently runs on local mock/demo data.

Architecture has been prepared for backend integration:
- feature-based structure
- Riverpod state management
- separation between presentation / domain / data
- reusable filtering and taxonomy models

Next integration target:
- eBay Browse API
- search listings
- pricing
- sorting
- market trend data

## Planned API Integration

First external integration:
- eBay Browse API

Planned capabilities:
- keyword search
- brand/IP filtering
- listing price sorting
- trending market feed
- sold/completed price research (future)