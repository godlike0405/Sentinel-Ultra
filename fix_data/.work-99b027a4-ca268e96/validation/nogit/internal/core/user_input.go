package core

type UserInputOption struct {
	Label       string `json:"label"`
	Description string `json:"description"`
}

type UserInputQuestion struct {
	Header   string            `json:"header"`
	ID       string            `json:"id"`
	Question string            `json:"question"`
	Options  []UserInputOption `json:"options"`
}

type UserInputRequest struct {
	Questions []UserInputQuestion `json:"questions"`
}

type UserInputAnswer struct {
	ID      string `json:"id"`
	Label   string `json:"label"`
	Value   string `json:"value"`
	IsOther bool   `json:"is_other,omitempty"`
}

type UserInputResponse struct {
	Answers []UserInputAnswer `json:"answers"`
}
