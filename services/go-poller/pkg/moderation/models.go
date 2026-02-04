package moderation

import (
	"time"

	"github.com/MargoRSq/infatium-mono/services/go-poller/internal/domain"
)

func ToModerationAction(action Action) domain.ModerationAction {
	switch action {
	case ActionAllow:
		return domain.ModerationActionAllow
	case ActionBlock:
		return domain.ModerationActionBlock
	case ActionFlag:
		return domain.ModerationActionFlag
	default:
		return domain.ModerationActionAllow
	}
}

func ToModerationLabels(labels []Label) []string {
	result := make([]string, len(labels))
	for i, label := range labels {
		result[i] = string(label)
	}
	return result
}

type ModerationResult struct {
	Action       domain.ModerationAction
	Labels       []string
	BlockReasons []string
	CheckedAt    time.Time
}

func FromCheckResponse(resp *CheckResponse) ModerationResult {
	if resp == nil {
		return ModerationResult{
			Action:    domain.ModerationActionAllow,
			Labels:    []string{string(LabelSafe)},
			CheckedAt: time.Now().UTC(),
		}
	}

	return ModerationResult{
		Action:       ToModerationAction(resp.Action),
		Labels:       ToModerationLabels(resp.Labels),
		BlockReasons: resp.BlockReasons,
		CheckedAt:    resp.CheckedAt,
	}
}
