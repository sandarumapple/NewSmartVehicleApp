import Foundation
import Testing
@testable import SmartVehicle

@Suite("Models and Community")
struct ModelsAndCommunityTests {
    @Test("Distance to service returns remaining kilometres")
    func distanceToServiceReturnsRemainingKilometres() {
        let vehicle = makeVehicle(mileage: 68_000, nextServiceMileage: 70_000)

        #expect(vehicle.distanceToService == 2_000)
    }

    @Test("Distance to service never becomes negative")
    func distanceToServiceNeverBecomesNegative() {
        let vehicle = makeVehicle(mileage: 72_000, nextServiceMileage: 70_000)

        #expect(vehicle.distanceToService == 0)
    }

    @Test("Marketplace price removes currency formatting")
    func marketplacePriceAmountRemovesCurrencyFormatting() {
        let listing = MarketplaceItem(
            title: "Toyota Aqua G",
            subtitle: "2018 · Hybrid · 68,500 km",
            price: "LKR 8,450,000",
            category: "Vehicles",
            symbol: "car.side.fill",
            tint: "blue",
            distance: "Colombo"
        )

        #expect(listing.priceAmount == 8_450_000)
    }

    @Test("Marketplace photo survives an encoding round trip")
    func marketplacePhotoSurvivesEncodingRoundTrip() throws {
        let photo = Data([0x01, 0x02, 0x03])
        let listing = MarketplaceItem(
            title: "Tyre set",
            subtitle: "Set of four",
            price: "LKR 112,000",
            category: "Spare parts",
            symbol: "circle.dashed",
            tint: "blue",
            distance: "Colombo",
            imageData: photo
        )

        let encoded = try JSONEncoder().encode(listing)
        let decoded = try JSONDecoder().decode(MarketplaceItem.self, from: encoded)

        #expect(decoded.imageData == photo)
    }

    @Test("Community search ignores punctuation and case")
    func communitySearchMatchesVehicleWordsIgnoringPunctuationAndCase() {
        let posts = [
            makePost(vehicle: "Toyota Aqua - 2018", authorID: "driver-a"),
            makePost(vehicle: "Honda Vezel 2020", authorID: "driver-b"),
        ]

        let result = CommunityFeedViewModel.visiblePosts(
            posts,
            category: "All posts",
            vehicleQuery: "TOYOTA aqua",
            authorFilter: .everyone,
            currentUserID: "current-user"
        )

        #expect(result.map(\.vehicle) == ["Toyota Aqua - 2018"])
    }

    @Test("Community filters other drivers and question categories")
    func communityFiltersOtherDriversAndQuestionCategories() {
        let currentUserID = "current-user"
        var ownPost = makePost(vehicle: "Toyota Aqua 2018", authorID: currentUserID)
        ownPost.category = "Question"
        var otherQuestion = makePost(vehicle: "Toyota Aqua 2020", authorID: "driver-b")
        otherQuestion.category = "Problem"
        var otherTip = makePost(vehicle: "Toyota Aqua 2019", authorID: "driver-c")
        otherTip.category = "Tip"

        let result = CommunityFeedViewModel.visiblePosts(
            [ownPost, otherQuestion, otherTip],
            category: "Questions",
            vehicleQuery: "Toyota Aqua",
            authorFilter: .otherDrivers,
            currentUserID: currentUserID
        )

        #expect(result.count == 1)
        #expect(result.first?.authorID == "driver-b")
        #expect(result.first?.category == "Problem")
    }

    private func makeVehicle(mileage: Int, nextServiceMileage: Int) -> Vehicle {
        Vehicle(
            make: "Toyota",
            model: "Aqua",
            year: 2018,
            registration: "CAA-1234",
            mileage: mileage,
            fuel: "Hybrid",
            color: "White",
            image: "car.side.fill",
            nextServiceMileage: nextServiceMileage,
            nextServiceDate: Date(timeIntervalSince1970: 0),
            vin: "TESTVIN123",
            engine: "1500cc",
            transmission: "Automatic"
        )
    }

    private func makePost(vehicle: String, authorID: String) -> CommunityPost {
        CommunityPost(
            author: "Test Driver",
            initials: "TD",
            vehicle: vehicle,
            time: "Just now",
            text: "Test community post",
            category: "Question",
            comments: 0,
            likes: 0,
            authorID: authorID
        )
    }
}
