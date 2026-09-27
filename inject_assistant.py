import re

with open("blood_pulse/lib/features/assistant/presentation/screens/assistant_screen.dart", "r", encoding="utf-8") as f:
    content = f.read()

injection = """
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Future.delayed(const Duration(seconds: 3), () {
        _textController.text = 'I weigh 49kg, can I donate?';
        _sendMessage();
      });
    });
  }
"""

if "void initState()" not in content:
    content = content.replace("class _AssistantScreenState extends ConsumerState<AssistantScreen> {", "class _AssistantScreenState extends ConsumerState<AssistantScreen> {\n" + injection)

with open("blood_pulse/lib/features/assistant/presentation/screens/assistant_screen.dart", "w", encoding="utf-8") as f:
    f.write(content)
print("Injected auto-send into AssistantScreen")
