Widget buildChatInput() {
  return Container(
    padding: EdgeInsets.all(12),
    child: TextField(
      decoration: InputDecoration(
        hintText: "Ask UniGuide anything...",
        filled: true,
        fillColor: Colors.grey[200],
        suffixIcon: IconButton(icon: Icon(Icons.send), onPressed: () {}),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(30), // Rounded Gemini-look
          borderSide: BorderSide.none,
        ),
      ),
    ),
  );
}