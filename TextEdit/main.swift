//
//  main.swift
//  TextEdit
//
//  Created by Shudhesh Velusamy on 10/15/25.
//

import Foundation
import Darwin

var originalTerm = termios()
func enableRawMode() {
    // get current settings
    tcgetattr(STDIN_FILENO, &originalTerm)
    
    var raw = originalTerm
    // disable canonical mode (ICANON) and echo (ECHO)
    raw.c_lflag &= ~UInt(ECHO | ICANON)
    // disable software flow control so Ctrl+S / Ctrl+Q are passed through
    raw.c_iflag &= ~UInt(IXON)
    // apply immediately
    tcsetattr(STDIN_FILENO, TCSANOW, &raw)
}
func restoreTerminalAndExit(_ code: Int32) -> Never {
    // restore terminal before exit
    tcsetattr(STDIN_FILENO, TCSANOW, &originalTerm)
    print("\u{001B}[?1049l")
    exit(code)
}

// C-signal handler that restores terminal and exits
func signalHandler(_ sig: Int32) -> Void {
    // Use _exit to avoid Swift runtime issues in signal context,
    // but restore terminal first with synchronous tcsetattr
    tcsetattr(STDIN_FILENO, TCSANOW, &originalTerm)
    print("\u{001B}[?1049l")
    _exit(0)
}

signal(SIGINT, signalHandler)
signal(SIGTERM, signalHandler)

enableRawMode()
defer { tcsetattr(STDIN_FILENO, TCSANOW, &originalTerm) }


let fileURL = URL(fileURLWithPath: "/Users/sh050106/Desktop/TextEdit/TextEdit/new.txt")
print("\u{001B}[?1049h")  // switch to alternate buffer
print("Welcome to Text Edit!")
print("Press Ctrl+S to save!")
print()

var buffer = [UInt8]()

func getString(buffer: [UInt8]) -> String {
    if let str = String(bytes: buffer, encoding: .utf8) {
        return str
    }
    return ""
}

func getLastLine(buffer: [UInt8]) -> String {
    let lastReturnIndex = buffer.lastIndex(of: 10) ?? 0
    return getString(buffer: Array(buffer[lastReturnIndex...]))
}

func handleChar(byte: UInt8) {
    if byte == 10 || (byte >= 32 && byte < 127) { // Characters and Enter
        buffer.append(byte)
        print("\(String(UnicodeScalar(byte)))",terminator: "")
        
    } else if byte == 0x7f { // Backspace
        if let poppedByte = buffer.popLast() {
            if poppedByte == 10 {
                let lastReturnIndex = buffer.lastIndex(of: 10) // Find NL in the *remaining* buffer
                let charsInLine: Int
                
                if let index = lastReturnIndex {
                    // Case 1: A preceding newline exists.
                    // The line starts AFTER that newline (index + 1).
                    // Length = total_count - (index + 1).
                    charsInLine = buffer.count - (index + 1)
                } else {
                    // Case 2: No preceding newline. This is the very first line of the buffer.
                    // Length = total_count (e.g., for "a", length is 1)
                    charsInLine = buffer.count
                }
                if charsInLine > 0 {
                    print("\u{1B}[1A\u{1B}[\(charsInLine)C", terminator: "")
                } else {
                    print("\u{1B}[1A", terminator: "")
                }
                
            } else {
                print("\u{8} \u{8}", terminator: "")
            }
        }
        
    } else { // Unhandled
        print("\(String(byte, radix:16))", terminator: "")
    }
    fflush(stdout)
}

func capture() {
    var byte :UInt8 = 0
    let bytesRead = read(STDIN_FILENO, &byte, 1)
    if bytesRead == 1 {
        if byte == 0x13 {                // Ctrl+S (ASCII 19, 0x13)
            print("\n✅ Ctrl+S detected!")
            do{
                try getString(buffer: buffer).write(to: fileURL, atomically: true, encoding: .utf8)
            } catch {
                print("File did not save!")
            }
            restoreTerminalAndExit(0)
        } else if byte == 0x03 {         // Ctrl+C (ASCII 3)
            print("\nInterrupted (Ctrl+C). Exiting.")
            restoreTerminalAndExit(0)
        } else {
            handleChar(byte: byte)
        }
    } else {
        // read returned <= 0 -> likely EOF or error, restore and exit
        restoreTerminalAndExit(0)
    }
}
while true{
    capture()
}



