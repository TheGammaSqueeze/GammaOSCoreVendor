package com.gammaos.usbswitch;

import android.app.Activity;
import android.app.AlertDialog;
import android.content.DialogInterface;
import android.graphics.drawable.GradientDrawable;
import android.os.Bundle;
import android.util.TypedValue;
import android.view.Gravity;
import android.view.View;
import android.view.ViewGroup;
import android.widget.LinearLayout;
import android.widget.ScrollView;
import android.widget.TextView;
import android.widget.Toast;

/**
 * GammaOS USB Mode switch for the GKD ATOM (RK3576).
 *
 * Normal (default) = the port acts as a USB device: charging, file transfer (MTP) and ADB.
 * OTG Host = the port acts as a USB host so keyboards, mice, gamepads and drives work.
 *
 * The app only sets a property. A root init service (init.gammaos_usb.rc + gammaos_usbmode.sh)
 * applies the Type-C port role in real time (no reboot needed to change the role). Because the
 * Type-C controller will not re-negotiate a cable that was already connected when the role
 * changed, a Restart action is offered for the case where an already-attached device is not
 * detected after switching to OTG.
 */
public class MainActivity extends Activity {

    private static final String MODE_PROP   = "persist.gammaos.usb.mode";
    private static final String REBOOT_PROP = "sys.gammaos.usb.reboot";

    private static final int BG     = 0xFF0E1116;
    private static final int CARD   = 0xFF161B22;
    private static final int CARDHI = 0xFF1F2A3A;   // focused
    private static final int ACCENT = 0xFF3DA5FF;   // active accent
    private static final int TEXT   = 0xFFECEFF4;
    private static final int SUBTLE = 0xFF9AA4B2;

    private TextView mStatus;
    private LinearLayout mNormalCard, mOtgCard, mRestartCard;

    @Override
    protected void onCreate(Bundle b) {
        super.onCreate(b);

        ScrollView scroll = new ScrollView(this);
        scroll.setBackgroundColor(BG);
        scroll.setFillViewport(true);

        LinearLayout root = new LinearLayout(this);
        root.setOrientation(LinearLayout.VERTICAL);
        root.setGravity(Gravity.CENTER_HORIZONTAL);
        int pad = dp(28);
        root.setPadding(pad, dp(24), pad, dp(24));
        scroll.addView(root);

        TextView title = new TextView(this);
        title.setText(getString(R.string.header_title));
        title.setTextColor(TEXT);
        title.setTextSize(TypedValue.COMPLEX_UNIT_SP, 30);
        title.setTypeface(title.getTypeface(), android.graphics.Typeface.BOLD);
        root.addView(title);

        TextView sub = new TextView(this);
        sub.setText(getString(R.string.header_subtitle));
        sub.setTextColor(SUBTLE);
        sub.setTextSize(TypedValue.COMPLEX_UNIT_SP, 15);
        sub.setPadding(0, dp(4), 0, dp(20));
        root.addView(sub);

        mNormalCard = buildCard(root,
                getString(R.string.mode_normal_title),
                getString(R.string.mode_normal_desc),
                new Runnable() { public void run() { selectNormal(); } });

        mOtgCard = buildCard(root,
                getString(R.string.mode_otg_title),
                getString(R.string.mode_otg_desc),
                new Runnable() { public void run() { selectOtg(); } });

        mRestartCard = buildCard(root,
                getString(R.string.restart_title),
                getString(R.string.restart_desc),
                new Runnable() { public void run() { restartDevice(); } });

        mStatus = new TextView(this);
        mStatus.setTextColor(SUBTLE);
        mStatus.setTextSize(TypedValue.COMPLEX_UNIT_SP, 14);
        mStatus.setPadding(0, dp(18), 0, 0);
        root.addView(mStatus);

        TextView hint = new TextView(this);
        hint.setText(getString(R.string.hint_navigate, confirmGlyph()));
        hint.setTextColor(0xFF6B7482);
        hint.setTextSize(TypedValue.COMPLEX_UNIT_SP, 13);
        hint.setPadding(0, dp(10), 0, 0);
        root.addView(hint);

        // Vertical D-pad focus order: Normal -> OTG -> Restart.
        mNormalCard.setNextFocusDownId(mOtgCard.getId());
        mOtgCard.setNextFocusUpId(mNormalCard.getId());
        mOtgCard.setNextFocusDownId(mRestartCard.getId());
        mRestartCard.setNextFocusUpId(mOtgCard.getId());

        setContentView(scroll);
        refresh();
    }

    private LinearLayout buildCard(ViewGroup parent, final String name, String desc, final Runnable onSelect) {
        final LinearLayout card = new LinearLayout(this);
        card.setId(View.generateViewId());
        card.setOrientation(LinearLayout.VERTICAL);
        card.setFocusable(true);
        card.setClickable(true);
        int p = dp(18);
        card.setPadding(p, p, p, p);
        card.setBackground(cardBackground(false));

        LinearLayout.LayoutParams lp = new LinearLayout.LayoutParams(
                dp(520), ViewGroup.LayoutParams.WRAP_CONTENT);
        lp.topMargin = dp(12);
        card.setLayoutParams(lp);

        final TextView tName = new TextView(this);
        tName.setText(name);
        tName.setTextColor(TEXT);
        tName.setTextSize(TypedValue.COMPLEX_UNIT_SP, 21);
        tName.setTypeface(tName.getTypeface(), android.graphics.Typeface.BOLD);
        card.addView(tName);

        TextView tDesc = new TextView(this);
        tDesc.setText(desc);
        tDesc.setTextColor(SUBTLE);
        tDesc.setTextSize(TypedValue.COMPLEX_UNIT_SP, 14);
        tDesc.setPadding(0, dp(6), 0, 0);
        card.addView(tDesc);

        TextView tBadge = new TextView(this);
        tBadge.setTextColor(ACCENT);
        tBadge.setTextSize(TypedValue.COMPLEX_UNIT_SP, 13);
        tBadge.setTypeface(tBadge.getTypeface(), android.graphics.Typeface.BOLD);
        tBadge.setPadding(0, dp(8), 0, 0);
        tBadge.setVisibility(View.GONE);
        card.addView(tBadge);
        card.setTag(tBadge);

        card.setOnFocusChangeListener(new View.OnFocusChangeListener() {
            public void onFocusChange(View v, boolean focused) { v.setBackground(cardBackground(focused)); }
        });
        card.setOnClickListener(new View.OnClickListener() {
            public void onClick(View v) { onSelect.run(); }
        });
        parent.addView(card);
        return card;
    }

    private GradientDrawable cardBackground(boolean focused) {
        GradientDrawable g = new GradientDrawable();
        g.setColor(focused ? CARDHI : CARD);
        g.setCornerRadius(dp(14));
        g.setStroke(dp(focused ? 2 : 1), focused ? ACCENT : 0xFF2A313B);
        return g;
    }

    private void refresh() {
        boolean otg = "otg".equals(getProp(MODE_PROP, "normal"));
        badge(mNormalCard, !otg);
        badge(mOtgCard, otg);
        String mode = otg ? getString(R.string.mode_otg_title) : getString(R.string.mode_normal_title);
        mStatus.setText(getString(R.string.status_current_mode, mode));
        // focus the active mode card by default
        (otg ? mOtgCard : mNormalCard).requestFocus();
    }

    private void badge(LinearLayout card, boolean active) {
        TextView badge = (TextView) card.getTag();
        badge.setText("●  " + getString(R.string.badge_active));   // ● ACTIVE
        badge.setVisibility(active ? View.VISIBLE : View.GONE);
    }

    private void selectNormal() {
        if ("normal".equals(getProp(MODE_PROP, "normal"))) {
            Toast.makeText(this, getString(R.string.toast_already_normal), Toast.LENGTH_SHORT).show();
            return;
        }
        setProp(MODE_PROP, "normal");
        Toast.makeText(this, getString(R.string.toast_normal_enabled), Toast.LENGTH_LONG).show();
        refresh();
    }

    private void selectOtg() {
        if ("otg".equals(getProp(MODE_PROP, "normal"))) {
            Toast.makeText(this, getString(R.string.toast_already_otg), Toast.LENGTH_SHORT).show();
            return;
        }
        // Applied live by the root init service; no reboot needed to change the role.
        setProp(MODE_PROP, "otg");
        Toast.makeText(this, getString(R.string.toast_otg_enabled), Toast.LENGTH_LONG).show();
        refresh();
    }

    private void restartDevice() {
        AlertDialog dlg = new AlertDialog.Builder(this, android.R.style.Theme_DeviceDefault_Dialog_Alert)
                .setTitle(getString(R.string.dialog_restart_title))
                .setMessage(getString(R.string.dialog_restart_message))
                .setPositiveButton(getString(R.string.action_restart), new DialogInterface.OnClickListener() {
                    public void onClick(DialogInterface d, int w) {
                        Toast.makeText(MainActivity.this, getString(R.string.toast_restarting), Toast.LENGTH_LONG).show();
                        // A root init rule reboots on this volatile trigger (never fires at boot).
                        setProp(REBOOT_PROP, "1");
                    }
                })
                .setNegativeButton(getString(R.string.action_cancel), null)
                .create();
        dlg.show();
    }

    private String confirmGlyph() { return "Ⓐ"; }   // Ⓐ (A)

    private int dp(int v) {
        return (int) TypedValue.applyDimension(TypedValue.COMPLEX_UNIT_DIP, v, getResources().getDisplayMetrics());
    }

    // ---- SystemProperties via reflection (available to system apps) ----
    private static String getProp(String key, String def) {
        try {
            Class<?> c = Class.forName("android.os.SystemProperties");
            return (String) c.getMethod("get", String.class, String.class).invoke(null, key, def);
        } catch (Throwable t) { return def; }
    }
    private static void setProp(String key, String val) {
        try {
            Class<?> c = Class.forName("android.os.SystemProperties");
            c.getMethod("set", String.class, String.class).invoke(null, key, val);
        } catch (Throwable t) { }
    }
}
