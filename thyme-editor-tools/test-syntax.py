#!/usr/bin/env python3
"""
Test file for syntax highlighting in Thyme OS editor
This Python script demonstrates various syntax elements
"""

import os
import sys
from typing import List, Dict

def hello_thyme() -> str:
    """Return a greeting for Thyme OS"""
    name = "Thyme OS"
    version = 1.0
    
    # This is a comment
    message = f"Hello from {name} v{version}!"
    
    # Dictionary with various data types
    config = {
        "debug": True,
        "max_connections": 100,
        "timeout": 30.5,
        "features": ["syntax-highlighting", "macbook-support"]
    }
    
    return message

class ThymeEditor:
    """A simple class to demonstrate syntax highlighting"""
    
    def __init__(self, filename: str):
        self.filename = filename
        self.content = ""
    
    def load_file(self) -> bool:
        try:
            with open(self.filename, 'r') as f:
                self.content = f.read()
            return True
        except FileNotFoundError:
            print(f"Error: File {self.filename} not found")
            return False
    
    def highlight_syntax(self):
        """This function would add syntax highlighting"""
        keywords = ["def", "class", "import", "if", "else", "for", "while"]
        # Implementation would go here
        pass

if __name__ == "__main__":
    print(hello_thyme())
    
    # Test editor functionality
    editor = ThymeEditor("test.txt")
    if editor.load_file():
        editor.highlight_syntax()
        print("✅ Syntax highlighting test passed!")
    else:
        print("❌ File loading failed")