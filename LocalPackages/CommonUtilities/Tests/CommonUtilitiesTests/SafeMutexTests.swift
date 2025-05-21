//
// SafeMutexTests.swift
// Proton Authenticator - Created on 14/05/2025.
// Copyright (c) 2025 Proton Technologies AG
//
// This file is part of Proton Authenticator.
//
// Proton Authenticator is free software: you can redistribute it and/or modify
// it under the terms of the GNU General Public License as published by
// the Free Software Foundation, either version 3 of the License, or
// (at your option) any later version.
//
// Proton Authenticator is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
// GNU General Public License for more details.
//
// You should have received a copy of the GNU General Public License
// along with Proton Authenticator. If not, see https://www.gnu.org/licenses/.

import CommonUtilities
import Foundation
import Testing

struct SafeMutexTests {
    // MARK: - Basic Functionality Tests

    @Test func basicValueAccess() {
        let mutex = SafeMutex.create(42)
        #expect(mutex.value == 42)

        mutex.modify { value in
            value = 100
        }
        #expect(mutex.value == 100)
    }

    @Test func withLock() {
        let mutex = SafeMutex.create("hello")
        let result = mutex.withLock { value in
            value + " world"
        }

        #expect(result == "hello world")
        #expect(mutex.value == "hello") // Original value unchanged
    }

    @Test func modify() {
        let mutex = SafeMutex.create([1, 2, 3])

        let result = mutex.modify { array in
            array.append(4)
            return array.count
        }

        #expect(result == 4)
        #expect(mutex.value == [1, 2, 3, 4])
    }

    // MARK: - Modern Concurrency Tests with async/await

    @Test func concurrentReadsAsync() async throws {
        let mutex = SafeMutex.create(42)

        await withTaskGroup(of: Void.self) { group in
            for _ in 0..<100 {
                group.addTask {
                    _ = mutex.value
                }
            }
        }

        // If no crashes or errors, the test passes
        #expect(mutex.value == 42)
    }

    @Test func concurrentWritesAsync() async throws {
        let mutex = SafeMutex.create(0)
        let iterations = 100

        await withTaskGroup(of: Void.self) { group in
            for _ in 0..<iterations {
                group.addTask {
                    mutex.modify { value in
                        value += 1
                    }
                }
            }
        }

        #expect(mutex.value == iterations)
    }

    @Test func concurrentModifyAsync() async throws {
        let mutex = SafeMutex.create(0)
        let iterations = 100

        await withTaskGroup(of: Void.self) { group in
            for _ in 0..<iterations {
                group.addTask {
                    mutex.modify { value in
                        value += 1
                    }
                }
            }
        }

        #expect(mutex.value == iterations, "Atomic modifications should result in exact count")
    }

    @Test func atomicIncrementPreventRaceConditionAsync() async throws {
        // This test demonstrates how modify prevents race conditions
        let mutex = SafeMutex.create(0)
        let iterations = 100

        await withTaskGroup(of: Void.self) { group in
            for _ in 0..<iterations {
                group.addTask {
                    // ATOMIC operation - read and write in one critical section
                    mutex.modify { value in
                        value += 1
                    }
                }
            }
        }

        #expect(mutex.value == iterations, "Atomic modifications should result in exact count")
    }

    @Test func randomAccessPatternAsync() async throws {
        let mutex = SafeMutex.create([Int: Int]())
        let iterations = 100

        await withTaskGroup(of: Void.self) { group in
            for i in 0..<iterations {
                group.addTask {
                    let key = Int.random(in: 0..<100)
                    mutex.modify { dict in
                        dict[key] = i
                        return dict.count
                    }
                }
            }
        }

        // Test passes if no crashes occurred during concurrent access
        #expect(mutex.value.count <= 100)
    }

    @Test func interleavedReadWriteAsync() async throws {
        let mutex = SafeMutex.create(0)

        await withTaskGroup(of: Void.self) { group in
            // Add 1000 write tasks
            for i in 0..<1_000 {
                group.addTask {
                    mutex.modify { value in
                        value = i
                    }
                }
            }

            // Add 1000 read tasks
            for _ in 0..<1_000 {
                group.addTask {
                    _ = mutex.value
                }
            }

            // Add 1000 modify tasks
            for _ in 0..<1_000 {
                group.addTask {
                    mutex.modify { value in
                        value += 1
                    }
                }
            }
        }

        // The actual value doesn't matter - we're testing for race conditions
        // If this completes without crashing, the test passes
    }

    @Test func concurrentComplexOperationsAsync() async throws {
        struct User: Sendable, Equatable {
            var id: Int
            var name: String
            var score: Double
        }

        let mutex = SafeMutex.create([User]())

        await withTaskGroup(of: Void.self) { group in
            // Task 1: Add users
            for i in 0..<100 {
                group.addTask {
                    mutex.modify { users in
                        users.append(User(id: i, name: "User\(i)", score: Double(i)))
                    }
                }
            }

            // Task 2: Update random user scores
            for _ in 0..<100 {
                group.addTask {
                    mutex.modify { users in
                        if let randomIndex = users.indices.randomElement() {
                            users[randomIndex].score += 10
                        }
                    }
                }
            }

            // Task 3: Read the current state
            for _ in 0..<100 {
                group.addTask {
                    _ = mutex.value
                }
            }
        }

        // Should have added 100 users
        #expect(mutex.value.count == 100)
    }

    // MARK: - Performance Tests

    @Test func performanceModifyAsync() async throws {
        let mutex = SafeMutex.create(0)

        let startTime = Date()

        await withTaskGroup(of: Void.self) { group in
            for _ in 0..<100 {
                group.addTask {
                    mutex.modify { value in
                        value += 1
                    }
                }
            }
        }

        let duration = Date().timeIntervalSince(startTime)
        print("Time to complete 100,000 atomic increments: \(duration) seconds")

        #expect(mutex.value == 100)
    }
}
