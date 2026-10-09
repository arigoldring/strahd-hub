import { useState } from "react";
import { signOut } from "../services/auth";
import { useAuth } from "../services/AuthContext";
import { NamePrompt } from "./NamePrompt";
import { usePlayerPreview } from "./PlayerPreviewContext";

/**
 * The two non-link controls the campaign chrome carries, pulled out so the
 * desktop rail and the phone's More sheet render the same component rather
 * than two copies of it. Class names stay the rail's; mobileNav.css restyles
 * them inside the sheet.
 */

/**
 * campaign.isDm, never the previewing-aware gate the pages use: this control
 * has to survive its own effect, or switching it on would take away the only
 * way to switch it back off. The caller does the isDm check.
 */
export function PreviewToggle() {
  const { previewing, setPreviewing } = usePlayerPreview();
  return (
    <button
      className={`app-rail__preview${previewing ? " is-on" : ""}`}
      onClick={() => setPreviewing(!previewing)}
    >
      {previewing ? "Exit player view" : "View as player"}
    </button>
  );
}

export function AccountControls() {
  const { profile } = useAuth();
  const [isEditing, setIsEditing] = useState(false);

  return (
    <div className="app-rail__you">
      {!isEditing ? (
        <p>
          {profile?.displayName}
          <button onClick={() => setIsEditing(true)}>Edit</button>
        </p>
      ) : (
        <NamePrompt
          initialName={profile?.displayName ?? ""}
          heading="Name:"
          onSuccess={() => setIsEditing(false)}
        />
      )}
      <p className="app-rail__signout">
        <button onClick={() => signOut()}>Sign out</button>
      </p>
    </div>
  );
}
