import Foundation

struct AnalysisEntityMatcher {
    func matches(entity: EntityNode, analysis: RecordAnalysisSnapshot) -> Bool {
        analysis.entities.contains { reference in
            reference.kind == entity.kind && matches(reference: reference, entity: entity)
        }
    }

    func matchedReference(entity: EntityNode, analysis: RecordAnalysisSnapshot) -> EntityReference? {
        analysis.entities.first { reference in
            reference.kind == entity.kind && matches(reference: reference, entity: entity)
        }
    }

    private func matches(reference: EntityReference, entity: EntityNode) -> Bool {
        normalized(reference.name) == normalized(entity.displayName)
            || normalized(reference.name) == normalized(entity.canonicalName)
            || normalized(reference.name) == normalized(entity.summary)
    }

    private func normalized(_ text: String) -> String {
        text
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current)
    }
}
