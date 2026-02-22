FidelShare

A role-based education platform built with Flutter that enables communication between students and class representatives through real-time messaging, announcements, and shared learning materials.

Overview

FidelShare is designed for educational institutions where communication and resource sharing need to be fast, structured, and reliable.

The app supports two main roles:

Student

Representative

Representatives can post announcements and upload materials, while students receive updates in real time.

Core Features

Role-based authentication (Student / Representative)

Real-time messaging using Supabase

Announcement system

Learning material sharing

Push notifications using Firebase Cloud Messaging

Backend hosting and services (e.g., AlwaysData)

Organized UI for academic communication

Tech Stack

Flutter

Supabase – Auth, PostgreSQL, Realtime

Firebase Cloud Messaging – Notifications

AlwaysData – Hosting / backend services (if API or file hosting)

State management: (write what you actually use)

Architecture Highlights

Role-based access control

Structured database schema (users, roles, announcements, materials, chats)

Realtime subscriptions for instant updates

Separation between messaging system and announcement feed

Now let’s talk seriously.

This project is MUCH stronger than a simple chat app.

Because now you’re dealing with:

Role-based logic

Permission control

Structured content

Realtime systems

Notifications

Backend hosting
