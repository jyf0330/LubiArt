extends RefCounted

## Immutable defaults for deterministic auto-position search. Policy owns
## ordering; candidate generation and planner pruning consume this configuration.

const CANDIDATE_LIMIT := 32
const TARGET_SIGNATURE_LIMIT := 6
const BEAM_WIDTH := 128
const SURVIVAL_FINALIST_LIMIT := 16
const ACTION_COUNT_DIVERSITY := 4
const APPROACH_CANDIDATE_LIMIT := 8
const STANDBY_CANDIDATE_LIMIT := 4


static func defaults() -> Dictionary:
	return {
		"candidateLimit": CANDIDATE_LIMIT,
		"targetSignatureLimit": TARGET_SIGNATURE_LIMIT,
		"approachCandidateLimit": APPROACH_CANDIDATE_LIMIT,
		"standbyCandidateLimit": STANDBY_CANDIDATE_LIMIT,
		"beamWidth": BEAM_WIDTH,
		"survivalFinalistLimit": SURVIVAL_FINALIST_LIMIT,
		"actionCountDiversity": ACTION_COUNT_DIVERSITY
	}
