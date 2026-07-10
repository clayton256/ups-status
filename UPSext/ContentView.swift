//
//  ContentView.swift
//  UPSext
//
//  Created by Mark Clayton on 11/15/25.
//

import SwiftUI
import SwiftData
import OSLog
import Foundation
import IOKit.ps

struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var items: [Item]

    var body: some View {
        NavigationSplitView {
            List {
                ForEach(items) { item in
                    NavigationLink {
                        Text("Item at \(item.timestamp, format: Date.FormatStyle(date: .numeric, time: .standard))")
                    } label: {
                        Text(item.timestamp, format: Date.FormatStyle(date: .numeric, time: .standard))
                    }
                }
                .onDelete(perform: deleteItems)
            }
#if os(macOS)
            .navigationSplitViewColumnWidth(min: 180, ideal: 200)
#endif
            .toolbar {
#if os(iOS)
                ToolbarItem(placement: .navigationBarTrailing) {
                    EditButton()
                }
#endif
                ToolbarItem {
                    Button {
                        Task {
                            let psInfo = await retrievePowerSourcesInfo()
//                            let logs = await readLogs()
//                            // For now, log to console; you can present this in UI later
                            print(psInfo)
                        }
                    } label: {
                        Label("Read Logs", systemImage: "plus")
                    }
                }
            }
        } detail: {
            Text("Select an item")
        }
    }

    private func addItem() {
        withAnimation {
            let newItem = Item(timestamp: Date())
            modelContext.insert(newItem)
        }
    }

    private func deleteItems(offsets: IndexSet) {
        withAnimation {
            for index in offsets {
                modelContext.delete(items[index])
            }
        }
    }
        
    private func retrievePowerSourcesInfo() async -> String {
        if let powerSourcesInfo = IOPSCopyPowerSourcesInfo()?.takeRetainedValue() {
            //CFShow(powerSourcesInfo)
            
            if let sourcesList = IOPSCopyPowerSourcesList(powerSourcesInfo)?.takeRetainedValue() {
                //CFShow(sourcesList)
                if let nameValue = CFDictionaryGetValue(sourcesList as! CFDictionary,Unmanaged.passUnretained(kIOPSNameKey as CFString).toOpaque()) {
                    print(nameValue)
                } else {
                    return "Couldn't retrieve 'Name' key"
                }
            } else {
                return "IOPSCopyPowerSourcesList returned nil"
            }
        }
        return "Failed to get power sources info"
    }
    
    private func readLogs() async -> String {
        do {
            let store = try OSLogStore(scope: .currentProcessIdentifier)
            let position = store.position(timeIntervalSinceLatestBoot: 1)
            // https://useyourloaf.com/blog/fetching-oslog-messages-in-swift/ for NSPredicate examples
            let predicate = NSPredicate(format: "subsystem BEGINSWITH %@", "com.apple.TimeMachine")
            let entries = try store.getEntries(at: position, matching: predicate)
                .compactMap { $0 as? OSLogEntryLog }
                //.filter { $0.subsystem == "com.apple.mail" }
            return entries.map { "[\($0.date)] [\($0.category)] \($0.composedMessage)" }
                          .joined(separator: "\n")
        } catch {
            return "Failed to fetch logs: \(error)"
        }
    }
}

#Preview {
    ContentView()
        .modelContainer(for: Item.self, inMemory: true)
}

