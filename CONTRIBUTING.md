# Contributing to Favorite Places

Thank you for your interest in contributing to Favorite Places! 🎉

## 📋 Table of Contents

- [Code of Conduct](#code-of-conduct)
- [How Can I Contribute?](#how-can-i-contribute)
- [Development Setup](#development-setup)
- [Pull Request Process](#pull-request-process)
- [Coding Guidelines](#coding-guidelines)
- [Commit Messages](#commit-messages)

## 📜 Code of Conduct

### Our Pledge

We are committed to providing a welcoming and inclusive experience for everyone. We do not tolerate harassment of participants in any form.

### Our Standards

**Examples of behavior that contributes to a positive environment:**
- Being respectful of differing viewpoints and experiences
- Gracefully accepting constructive criticism
- Focusing on what is best for the community
- Showing empathy towards other community members

**Examples of unacceptable behavior:**
- Trolling, insulting/derogatory comments, and personal attacks
- Public or private harassment
- Publishing others' private information without permission
- Other conduct which could reasonably be considered inappropriate

## 🤝 How Can I Contribute?

### Reporting Bugs

**Before submitting a bug report:**
- Check the existing issues to avoid duplicates
- Collect relevant information (OS, Flutter version, error logs)

**How to submit a good bug report:**
1. Use a clear and descriptive title
2. Describe the exact steps to reproduce the problem
3. Provide specific examples
4. Describe the behavior you observed and what you expected
5. Include screenshots if applicable
6. Include your environment details (OS, Flutter version, etc.)

### Suggesting Enhancements

**Before submitting an enhancement suggestion:**
- Check if it's already been suggested
- Check if the feature aligns with the project's scope

**How to submit a good enhancement suggestion:**
1. Use a clear and descriptive title
2. Provide a detailed description of the suggested enhancement
3. Explain why this enhancement would be useful
4. Include mockups or examples if applicable

### Pull Requests

We actively welcome your pull requests!

**Good first issues:**
- Documentation improvements
- Bug fixes
- UI/UX improvements
- Adding tests
- Performance optimizations

## 🛠️ Development Setup

### Prerequisites

- Flutter 3.7+
- Node.js 18+
- Git
- Firebase account
- Google Gemini API key (free)

### Setup Steps

1. **Fork and clone the repository**
   ```bash
   git clone https://github.com/YOUR_USERNAME/FavoritePlaces.git
   cd FavoritePlaces
   ```

2. **Set up the backend**
   ```bash
   cd backend
   npm install
   cp .env.example .env
   # Edit .env with your credentials
   npm run dev
   ```

3. **Set up the mobile app**
   ```bash
   cd mobile
   flutter pub get
   cp lib/config.example.dart lib/config.dart
   # Edit config.dart with your API keys
   flutter run
   ```

4. **Create a feature branch**
   ```bash
   git checkout -b feature/my-awesome-feature
   ```

## 🔄 Pull Request Process

1. **Update documentation** if you're changing functionality
2. **Add tests** for new features
3. **Ensure all tests pass**
   ```bash
   # Flutter tests
   cd mobile && flutter test
   
   # Backend tests (if available)
   cd backend && npm test
   ```
4. **Follow the coding guidelines** (see below)
5. **Update the README.md** if needed
6. **Create the Pull Request** with a clear description

### PR Description Template

```markdown
## Description
Brief description of what this PR does

## Type of Change
- [ ] Bug fix
- [ ] New feature
- [ ] Breaking change
- [ ] Documentation update

## Testing
Describe how you tested your changes

## Screenshots (if applicable)
Add screenshots here

## Checklist
- [ ] My code follows the project's coding guidelines
- [ ] I have commented my code, particularly in hard-to-understand areas
- [ ] I have updated the documentation accordingly
- [ ] My changes generate no new warnings
- [ ] I have added tests that prove my fix/feature works
- [ ] New and existing tests pass locally
```

## 📝 Coding Guidelines

### Dart/Flutter Guidelines

**Follow Flutter style guide:**
- Use `lowerCamelCase` for variables and functions
- Use `UpperCamelCase` for classes
- Use `snake_case` for file names
- Maximum line length: 80 characters (flexible to 100 for readability)

**Example:**
```dart
// Good
class PlaceDetailScreen extends StatelessWidget {
  final Place place;
  
  const PlaceDetailScreen({super.key, required this.place});
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(place.title)),
      body: _buildBody(),
    );
  }
  
  Widget _buildBody() {
    // Implementation
  }
}

// Bad
class placedetailscreen extends StatelessWidget {
  Place Place;
  
  placedetailscreen(this.Place);
  
  Widget build(context) {
    return Scaffold(appBar: AppBar(title: Text(Place.title)), body: Container());
  }
}
```

**Code organization:**
- Group imports: Dart SDK → Flutter → Third-party → Project
- Use meaningful variable names
- Keep functions small and focused
- Add comments for complex logic

### JavaScript/Node.js Guidelines

**Follow standard JavaScript conventions:**
- Use `camelCase` for variables and functions
- Use `PascalCase` for classes
- Use `UPPER_SNAKE_CASE` for constants
- Use 2 spaces for indentation

**Example:**
```javascript
// Good
const MAX_RETRIES = 3;

class UserService {
  async getUserProfile(userId) {
    const user = await db.users.findById(userId);
    return this.formatUserData(user);
  }
  
  formatUserData(user) {
    return {
      id: user.id,
      name: user.displayName,
      email: user.email,
    };
  }
}

// Bad
const max_retries = 3;

class userservice {
  async GetUserProfile(user_id) {
    var User = await db.users.findById(user_id);
    return this.FormatUserData(User);
  }
}
```

**Code organization:**
- Use async/await over callbacks
- Handle errors properly with try-catch
- Use descriptive error messages
- Add JSDoc comments for functions

## 💬 Commit Messages

Follow the [Conventional Commits](https://www.conventionalcommits.org/) specification:

**Format:**
```
<type>(<scope>): <subject>

<body>

<footer>
```

**Types:**
- `feat`: New feature
- `fix`: Bug fix
- `docs`: Documentation changes
- `style`: Code style changes (formatting, etc.)
- `refactor`: Code refactoring
- `test`: Adding or updating tests
- `chore`: Maintenance tasks

**Examples:**

```bash
# Good commits
feat(mobile): Add dark mode support
fix(backend): Resolve Gemini API timeout issue
docs(readme): Update installation instructions
refactor(mobile): Simplify authentication flow

# Bad commits
update stuff
fix bug
changes
```

**Detailed example:**
```
feat(mobile): Add offline mode for viewing saved places

- Implement local caching with sqflite
- Add sync queue for pending uploads
- Show offline indicator in UI
- Handle conflicts on reconnection

Closes #123
```

## 🧪 Testing

### Writing Tests

**Flutter (mobile):**
```dart
// Example widget test
testWidgets('PlaceCard displays place information', (WidgetTester tester) async {
  final place = Place(
    id: '1',
    title: 'Test Place',
    category: PlaceCategory.restaurant,
  );
  
  await tester.pumpWidget(
    MaterialApp(home: PlaceCard(place: place)),
  );
  
  expect(find.text('Test Place'), findsOneWidget);
  expect(find.byIcon(Icons.restaurant), findsOneWidget);
});
```

**Node.js (backend):**
```javascript
// Example endpoint test
describe('GET /user/profile', () => {
  it('should return user profile when authenticated', async () => {
    const res = await request(app)
      .get('/user/profile')
      .set('Authorization', `Bearer ${validToken}`);
    
    expect(res.statusCode).toBe(200);
    expect(res.body).toHaveProperty('displayName');
  });
});
```

## 📦 Project-Specific Guidelines

### Mobile App

- **State Management:** Use Riverpod for state management
- **Navigation:** Use Flutter's standard navigation
- **Firebase:** All Firebase operations in `services/` folder
- **UI Components:** Reusable widgets in `widgets/` folder

### Backend

- **API Routes:** Organize in `routes/` folder
- **Middleware:** Authentication required for all `/ai/*` and `/user/*` routes
- **Error Handling:** Use try-catch and return proper HTTP status codes
- **Environment Variables:** Never commit `.env` or secrets

## 🎨 UI/UX Guidelines

- Follow Material Design 3 guidelines
- Maintain consistent spacing (8px grid)
- Use theme colors, not hardcoded colors
- Ensure accessibility (contrast ratios, tap targets)
- Support both light and dark themes

## 🚀 Release Process

1. Update version in `pubspec.yaml` and `package.json`
2. Update CHANGELOG.md
3. Create a release branch
4. Test thoroughly
5. Merge to main
6. Tag the release
7. Create GitHub release with notes

## ❓ Questions?

- Open an issue with the `question` label
- Check existing issues and discussions
- Be specific and provide context

## 🙏 Thank You!

Your contributions make this project better for everyone. We appreciate your time and effort!

---

**Happy coding! 🎉**