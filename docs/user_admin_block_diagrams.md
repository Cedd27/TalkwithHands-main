# User and Admin Block Diagrams

These diagrams describe the main application flows in Talk with Hands. They use Mermaid flowchart syntax and can be rendered by VS Code extensions, GitHub, or Mermaid Live.

## User Module

```mermaid
flowchart LR
    Login[Login / Register]
    Home[User Home]
    Lessons[Learning Modules]
    Alphabet[Alphabets]
    Numbers[Numbers]
    Words[Basic Words]
    Detector[Sign Detector]
    Games[Games]
    GuessASL[Guess ASL]
    GuessMe[Guess Me]
    Calculator[Calculator Game]
    Media[Learning Media]
    Tutorials[Tutorial Videos]
    Panorama[360 Panorama]
    Progress[Progress]
    Profile[Edit Profile / Settings]
    Logout[Logout]
    API[Backend API]
    ProgressAPI[Progress Service]

    Login --> Home
    Home --> Lessons
    Lessons --> Alphabet
    Lessons --> Numbers
    Lessons --> Words
    Home --> Detector
    Home --> Games
    Games --> GuessASL
    Games --> GuessMe
    Games --> Calculator
    Home --> Media
    Media --> Tutorials
    Media --> Panorama
    Home --> Progress
    Home --> Profile
    Home --> Logout

    Alphabet --> API
    Numbers --> API
    Words --> API
    Tutorials --> API
    Panorama --> API
    Detector --> ProgressAPI
    Games --> ProgressAPI
    Alphabet --> ProgressAPI
    Numbers --> ProgressAPI
    Words --> ProgressAPI
    Progress --> ProgressAPI
    Profile --> API
```

## Admin Module

```mermaid
flowchart LR
    Login[Login]
    AdminCheck{Admin Account?}
    AdminHome[Admin Area]
    Dashboard[Dashboard / Analytics]
    Analytics[User Activity and Progress Analytics]
    Content[Content Management]
    AlphabetContent[Manage Alphabet Signs]
    NumberContent[Manage Number Signs]
    WordsContent[Manage Basic Words]
    Media[Media and Uploads]
    Panorama[Manage Panorama Scenes]
    Users[User Accounts]
    Profile[Edit Admin Profile]
    Logout[Logout]
    API[Backend Admin API]
    Database[(User and Content Data)]

    Login --> AdminCheck
    AdminCheck -->|Yes| AdminHome
    AdminCheck -->|No| UserFlow[User Module]
    AdminHome --> Dashboard
    Dashboard --> Analytics
    AdminHome --> Content
    Content --> AlphabetContent
    Content --> NumberContent
    Content --> WordsContent
    AdminHome --> Media
    Media --> Panorama
    AdminHome --> Users
    AdminHome --> Profile
    AdminHome --> Logout

    Dashboard --> API
    Analytics --> API
    AlphabetContent --> API
    NumberContent --> API
    WordsContent --> API
    Media --> API
    Panorama --> API
    Users --> API
    Profile --> API
    API --> Database
```

## Main Backend Services

The Flutter and React Native clients communicate with the Node.js backend through these areas:

- Authentication and user profiles
- Alphabet signs
- Number signs
- Basic words
- Progress tracking
- Panorama scenes
- Media and video delivery
- Admin uploads
- Admin analytics