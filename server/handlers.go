package server

import (
	"errors"

	"code-harvest.conner.dev/domain"
)

// FocusGained is invoked by the FocusGained autocommand. It gives
// us information about the currently active client. The duration
// of a coding session should not increase by the number of clients
// (neovim instances). Only one will be tracked at a time.
func (server *server) FocusGained(event domain.Event, reply *string) error {
	// Lock the mutex to prevent race conditions with the heartbeat check.
	server.mutex.Lock()
	defer server.mutex.Unlock()

	server.lastHeartbeat = server.clock.GetTime()

	// The FocusGained event will be triggered when I switch back to an active
	// editor from another TMUX split. However, the intent is to only terminate
	// the current session, and initiate a new one, if I'm opening another neovim
	// instance. If the FocusGained event is firing because I'm jumping back and
	// forth between a tmux split with test output I don't want it to result in
	// the creation of several new coding sessions.
	if server.activeClientId == event.Id {
		server.log.PrintDebug("Jumped back to the same neovim instance", nil)
		return nil
	}

	// Check to see if we have another instance of neovim that is
	// running in another tmux pane. If so, we'll stop recording
	// time for that session before creating a new one.
	if server.session != nil {
		server.saveSession()
	}

	server.activeClientId = event.Id
	server.startNewSession(event.OS, event.Editor)

	// It could be an already existing neovim instance where a file buffer is already
	// open. If that is the case we can't count on getting the *OpenFile* event.
	// We might just be jumping between two neovim instances with one buffer each.
	server.setActiveBuffer(event.Path)
	*reply = "Successfully updated the client being focused."
	return nil
}

// OpenFile gets invoked by the *BufEnter* autocommand.
func (server *server) OpenFile(event domain.Event, reply *string) error {
	server.log.PrintDebug("Received OpenFile event", map[string]string{
		"path": event.Path,
	})

	// Lock the mutex to prevent race conditions with the heartbeat check.
	server.mutex.Lock()
	defer server.mutex.Unlock()

	// If a new file was opened it means that the session is still active.
	server.lastHeartbeat = server.clock.GetTime()

	// The BufEnter event might have fired after more than 10 minutes of
	// inactivity. If that is the case, the server would have ended our
	// coding session. A session that has ended is written to the file
	// system and can't be resumed. We'll have to create a new one.
	if server.session == nil {
		server.activeClientId = event.Id
		server.startNewSession(event.OS, event.Editor)
	}

	server.setActiveBuffer(event.Path)
	*reply = "Successfully updated the current file."
	return nil
}

// SendHeartbeat can be called for events such as buffer writes and cursor moves.
// Its purpose is to notify the server that the current session remains active.
// The server ends the session if it doesn't receive a heartbeat for 10 minutes.
func (server *server) SendHeartbeat(event domain.Event, reply *string) error {
	// Lock the mutex to prevent race conditions with the heartbeat check.
	server.mutex.Lock()
	defer server.mutex.Unlock()

	// This is to handle the case where the server would have ended the clients
	// session due to inactivity. When a session ends it is written to disk and
	// can't be resumed. Therefore, we'll have to create a new coding session.
	if server.session == nil {
		message := "The session was ended by a previous heartbeat check. Creating a new one."
		server.log.PrintDebug(message, map[string]string{
			"clientId": event.Id,
			"path":     event.Path,
		})
		server.activeClientId = event.Id
		server.startNewSession(event.OS, event.Editor)
		server.setActiveBuffer(event.Path)
	}

	// Update the time for the last heartbeat.
	server.lastHeartbeat = server.clock.GetTime()
	*reply = "Successfully sent heartbeat"
	return nil
}

// EndSession should be called by the *VimLeave* autocommand.
func (server *server) EndSession(event domain.Event, reply *string) error {
	// Lock the mutex to prevent race conditions with the heartbeat check.
	server.mutex.Lock()
	defer server.mutex.Unlock()

	// If we call end session, and there is another active client. It
	// means that the events have been sent in an unexpected order. As
	// a consequence, the server has reached an undesired state.
	if len(server.activeClientId) > 1 && server.activeClientId != event.Id {
		server.log.PrintFatal(errors.New("was called by a client that isn't considered active"), map[string]string{
			"actualClientId":   server.activeClientId,
			"expectedClientId": event.Id,
		})
	}

	// Theoretically, this could be the first event we receive after
	// more than ten minutes of inactivity. If that is the case the
	// server will have ended the session already.
	if server.activeClientId == "" && server.session == nil {
		message := "The session was already ended, or possibly never started"
		server.log.PrintDebug(message, nil)
		return nil
	}

	server.saveSession()
	*reply = "The session was ended successfully."
	return nil
}
