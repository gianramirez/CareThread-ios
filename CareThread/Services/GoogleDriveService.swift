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

    // TODO: Implement with GoogleSignIn-iOS SDK
    func signIn() async throws {
    }

    func signOut() {
        isSignedIn = false
        userName = nil
    }

    // TODO: Implement with GTLRDriveQuery_FilesCreate
    func uploadReport(title: String, content: String) async throws -> String {
        return "placeholder-file-id"
    }

    // TODO: Implement with GTLRDriveQuery_FilesList
    func listReports() async throws -> [(id: String, name: String, date: Date)] {
        return []
    }
}
