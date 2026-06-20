import Foundation

final class KTPAPIService {

    private let baseURL = URL(string: "http://localhost:3000/")!

    // check DirectoryMember.swift for the expected JSON structure
    func fetchDirectoryMembers() async throws -> [DirectoryMember] {
        let url = baseURL.appendingPathComponent("members")

        let (data, response) = try await URLSession.shared.data(from: url)

        guard let httpResponse = response as? HTTPURLResponse,
              200..<300 ~= httpResponse.statusCode else {
            throw URLError(.badServerResponse)
        }

        return try JSONDecoder().decode([DirectoryMember].self, from: data)
    }
    

   // func fetchMessageThreads() async throws -> [MessageThread] {
      //  let url = baseURL.appendingPathComponent("messages")

        //let (data, response) = try await URLSession.shared.data(from: url)

        //guard let httpResponse = response as? HTTPURLResponse,
          //    200..<300 ~= httpResponse.statusCode else {
            //throw URLError(.badServerResponse)
            //}

        //return try JSONDecoder().decode([MessageThread].self, from: data)
    }
