# Distributed Operating Systems

This repository contains exercises and projects for the course **Distributed Operating Systems**. It focuses on learning distributed programming concepts using **Gleam**, a functional language for building concurrent and distributed applications.

---

## Table of Contents

1. [Introduction](#introduction)
2. [Setting Up Gleam](#setting-up-gleam)
3. [Creating a New Project](#creating-a-new-project)
4. [Building and Running Projects](#building-and-running-projects)
5. [Testing](#testing)
6. [Adding/Removing Packages](#addingremoving-packages)
7. [Measuring Execution Time (MacOS)](#measuring-execution-time-macos)

---

## Introduction

Gleam is a statically typed, functional programming language designed for building robust concurrent and distributed applications. Its syntax is simple and safe, and it compiles to **Erlang VM**, allowing seamless integration with Erlang and Elixir ecosystems.

> **Note:** To run a project, you may need to change the `main` function in the `gleam.toml` file.

---

## Setting Up Gleam

1. Follow the official Gleam installation guide: [https://gleam.run/getting-started/installing/](https://gleam.run/getting-started/installing/)
2. Verify the installation:

   ```bash
   gleam --version
   ```

---

## Creating a New Project

```bash
gleam new <project_name>
```

This command generates a new Gleam project with the standard directory structure.

---

## Building and Running Projects

```bash
gleam build
gleam run
```

---

## Testing

```bash
gleam test
```

Runs all tests defined in your project.

---

## Adding/Removing Packages

```bash
gleam add <package>
gleam remove <package>
```

---

## Measuring Execution Time (MacOS)

```bash
time gleam run
```
