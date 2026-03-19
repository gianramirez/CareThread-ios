//
//  GoogleDriveService.swift
//  CareThread
//
//  Created by Gian Ramirez on 3/18/26.
//

import Foundation
import Observation

@Observable
class GoogleDriveService {
    var isSignedIn = false
    var userName: String?

    /// Sign in with Google
    /// TODO: Implement with GoogleSignIn-iOS SDK
    func signIn() async throws {
        print("Google Sign-In not yet implemented")
    }

    /// Sign out
    func signOut() {
        isSignedIn = false
        userName = nil
    }

    /// Upload a report to Google Drive as a Google Doc
    /// TODO: Implement with GTLRDriveQuery_FilesCreate
    func uploadReport(title: String, content: String) async throws -> String {
        print("Google Drive upload not yet implemented")
        return "placeholder-file-id"
    }

    /// List existing CareThread files in Drive
    /// TODO: Implement with GTLRDriveQuery_FilesList
    func listReports() async throws -> [(id: String, name: String, date: Date)] {
        return []
    }
}
