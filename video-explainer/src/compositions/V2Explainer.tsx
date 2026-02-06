import {AbsoluteFill, Sequence, useCurrentFrame, useVideoConfig, interpolate, spring} from 'remotion';

// 30 second video at 30fps = 900 frames
// Scene breakdown:
// - Intro: 0-120 (4s)
// - Terminal Command: 120-240 (4s)
// - 4 Modes Panel: 240-480 (8s)
// - Spec-Driven Deep Dive: 480-720 (8s)
// - Outro: 720-900 (6s)

export const V2Explainer: React.FC = () => {
	return (
		<AbsoluteFill style={{backgroundColor: '#0a0a0a'}}>
			<Sequence from={0} durationInFrames={120}>
				<IntroScene />
			</Sequence>

			<Sequence from={120} durationInFrames={120}>
				<TerminalScene />
			</Sequence>

			<Sequence from={240} durationInFrames={240}>
				<FourModesScene />
			</Sequence>

			<Sequence from={480} durationInFrames={240}>
				<SpecDrivenScene />
			</Sequence>

			<Sequence from={720} durationInFrames={180}>
				<OutroScene />
			</Sequence>
		</AbsoluteFill>
	);
};

// Scene 1: Intro with logo and v2.0 badge
const IntroScene: React.FC = () => {
	const frame = useCurrentFrame();
	const {fps} = useVideoConfig();

	const logoOpacity = interpolate(frame, [0, 20], [0, 1], {extrapolateRight: 'clamp'});
	const logoScale = spring({frame, fps, config: {damping: 200}});

	const badgeOpacity = interpolate(frame, [30, 50], [0, 1], {extrapolateRight: 'clamp'});
	const badgeScale = spring({frame: Math.max(0, frame - 30), fps, config: {damping: 12}});

	const taglineY = interpolate(frame, [50, 80], [50, 0], {extrapolateRight: 'clamp'});
	const taglineOpacity = interpolate(frame, [50, 80], [0, 1], {extrapolateRight: 'clamp'});

	return (
		<AbsoluteFill style={{justifyContent: 'center', alignItems: 'center', backgroundColor: '#0a0a0a'}}>
			{/* Logo */}
			<div style={{opacity: logoOpacity, transform: `scale(${logoScale})`, textAlign: 'center'}}>
				<div style={{
					fontSize: 100,
					fontWeight: 'bold',
					background: 'linear-gradient(135deg, #9333ea 0%, #3b82f6 100%)',
					WebkitBackgroundClip: 'text',
					WebkitTextFillColor: 'transparent',
					fontFamily: 'monospace',
				}}>
					feature-marker
				</div>

				{/* v2.0 Badge */}
				<div style={{
					opacity: badgeOpacity,
					transform: `scale(${badgeScale})`,
					display: 'inline-flex',
					marginTop: 20,
					backgroundColor: '#10b981',
					color: '#ffffff',
					fontSize: 28,
					fontWeight: 'bold',
					padding: '10px 30px',
					borderRadius: 50,
				}}>
					v2.0 🔬 Spec Kit Pattern
				</div>
			</div>

			{/* Tagline */}
			<div style={{
				position: 'absolute',
				bottom: '25%',
				opacity: taglineOpacity,
				transform: `translateY(${taglineY}px)`,
				textAlign: 'center',
			}}>
				<div style={{fontSize: 42, color: '#ffffff', fontWeight: 600}}>
					Automate feature development with AI-powered checkpoints
				</div>
			</div>
		</AbsoluteFill>
	);
};

// Scene 2: Terminal with command
const TerminalScene: React.FC = () => {
	const frame = useCurrentFrame();

	const terminalOpacity = interpolate(frame, [0, 15], [0, 1], {extrapolateRight: 'clamp'});

	const command = '/feature-marker --interactive my-feature';
	const typedLength = Math.floor(interpolate(frame, [20, 70], [0, command.length], {extrapolateRight: 'clamp'}));
	const typedCommand = command.substring(0, typedLength);

	const cursorBlink = Math.floor(frame / 15) % 2 === 0;
	const showCursor = frame < 80;

	return (
		<AbsoluteFill style={{justifyContent: 'center', alignItems: 'center', backgroundColor: '#0a0a0a', padding: 60}}>
			<div style={{
				opacity: terminalOpacity,
				backgroundColor: '#1e1e1e',
				borderRadius: 16,
				padding: 50,
				width: '85%',
				maxWidth: 1400,
				boxShadow: '0 25px 80px rgba(147, 51, 234, 0.25)',
				border: '1px solid #374151',
			}}>
				{/* Terminal header */}
				<div style={{display: 'flex', gap: 10, marginBottom: 35}}>
					<div style={{width: 14, height: 14, borderRadius: '50%', backgroundColor: '#ff5f56'}} />
					<div style={{width: 14, height: 14, borderRadius: '50%', backgroundColor: '#ffbd2e'}} />
					<div style={{width: 14, height: 14, borderRadius: '50%', backgroundColor: '#27c93f'}} />
					<div style={{marginLeft: 20, color: '#6b7280', fontSize: 18}}>Claude Code Terminal</div>
				</div>

				{/* Prompt + Command */}
				<div style={{display: 'flex', alignItems: 'center', fontFamily: 'monospace', fontSize: 38}}>
					<span style={{color: '#10b981'}}>❯</span>
					<span style={{color: '#9333ea', marginLeft: 15}}>{typedCommand}</span>
					{showCursor && <span style={{color: '#9333ea', opacity: cursorBlink ? 1 : 0}}>│</span>}
				</div>

				{/* Output hint */}
				{frame >= 85 && (
					<div style={{
						marginTop: 30,
						color: '#6b7280',
						fontSize: 24,
						opacity: interpolate(frame, [85, 100], [0, 1], {extrapolateRight: 'clamp'}),
					}}>
						Launching interactive execution panel...
					</div>
				)}
			</div>
		</AbsoluteFill>
	);
};

// Scene 3: Four Execution Modes
const FourModesScene: React.FC = () => {
	const frame = useCurrentFrame();

	const panelOpacity = interpolate(frame, [0, 20], [0, 1], {extrapolateRight: 'clamp'});
	const panelScale = interpolate(frame, [0, 20], [0.9, 1], {extrapolateRight: 'clamp'});

	// Highlight each mode sequentially
	const mode1Active = frame >= 30 && frame < 80;
	const mode2Active = frame >= 80 && frame < 130;
	const mode3Active = frame >= 130 && frame < 180;
	const mode4Active = frame >= 180;

	return (
		<AbsoluteFill style={{justifyContent: 'center', alignItems: 'center', backgroundColor: '#0a0a0a'}}>
			<div style={{
				opacity: panelOpacity,
				transform: `scale(${panelScale})`,
				backgroundColor: '#111111',
				borderRadius: 20,
				padding: 45,
				border: '2px solid #9333ea',
				boxShadow: '0 30px 80px rgba(147, 51, 234, 0.3)',
				minWidth: 950,
			}}>
				{/* Header */}
				<div style={{
					fontSize: 36,
					fontWeight: 'bold',
					color: '#ffffff',
					marginBottom: 35,
					textAlign: 'center',
					borderBottom: '1px solid #374151',
					paddingBottom: 20,
				}}>
					🚀 Feature Marker - 4 Execution Modes
				</div>

				<div style={{display: 'flex', flexDirection: 'column', gap: 20}}>
					<ModeOption num="1" title="Full Workflow" desc="Generate PRD/TechSpec/Tasks + Implementation" isActive={mode1Active} />
					<ModeOption num="2" title="Tasks Only" desc="Skip generation, run implementation" isActive={mode2Active} />
					<ModeOption num="3" title="Ralph Loop" desc="Autonomous self-correcting execution" isActive={mode3Active} />
					<ModeOption num="4" title="Spec-Driven Mode" desc="Multi-agent review + worktree isolation" isActive={mode4Active} isNew />
				</div>
			</div>
		</AbsoluteFill>
	);
};

const ModeOption: React.FC<{num: string; title: string; desc: string; isActive: boolean; isNew?: boolean}> = ({
	num, title, desc, isActive, isNew
}) => (
	<div style={{
		backgroundColor: isActive ? 'rgba(147, 51, 234, 0.15)' : 'transparent',
		border: isActive ? '2px solid #9333ea' : '2px solid transparent',
		borderRadius: 14,
		padding: 20,
		display: 'flex',
		alignItems: 'center',
		gap: 20,
	}}>
		<div style={{
			fontSize: 32,
			fontWeight: 'bold',
			color: isActive ? '#9333ea' : '#6b7280',
			minWidth: 50,
		}}>
			{num})
		</div>
		<div style={{flex: 1}}>
			<div style={{display: 'flex', alignItems: 'center', gap: 15}}>
				<span style={{fontSize: 26, fontWeight: 'bold', color: '#ffffff'}}>{title}</span>
				{isNew && (
					<span style={{
						backgroundColor: '#10b981',
						color: '#ffffff',
						fontSize: 14,
						fontWeight: 'bold',
						padding: '4px 12px',
						borderRadius: 20,
					}}>
						NEW v2.0
					</span>
				)}
			</div>
			<div style={{fontSize: 20, color: '#9ca3af', marginTop: 5}}>{desc}</div>
		</div>
	</div>
);

// Scene 4: Spec-Driven Mode Deep Dive
const SpecDrivenScene: React.FC = () => {
	const frame = useCurrentFrame();
	const {fps} = useVideoConfig();

	const titleOpacity = interpolate(frame, [0, 20], [0, 1], {extrapolateRight: 'clamp'});

	// Show each step sequentially
	const step1Opacity = interpolate(frame, [30, 50], [0, 1], {extrapolateRight: 'clamp'});
	const step2Opacity = interpolate(frame, [70, 90], [0, 1], {extrapolateRight: 'clamp'});
	const step3Opacity = interpolate(frame, [110, 130], [0, 1], {extrapolateRight: 'clamp'});
	const step4Opacity = interpolate(frame, [150, 170], [0, 1], {extrapolateRight: 'clamp'});

	// Personas appear
	const personasOpacity = interpolate(frame, [180, 200], [0, 1], {extrapolateRight: 'clamp'});

	return (
		<AbsoluteFill style={{backgroundColor: '#0a0a0a', padding: 60}}>
			{/* Title */}
			<div style={{
				opacity: titleOpacity,
				textAlign: 'center',
				marginBottom: 50,
			}}>
				<div style={{
					fontSize: 52,
					fontWeight: 'bold',
					background: 'linear-gradient(135deg, #9333ea 0%, #3b82f6 100%)',
					WebkitBackgroundClip: 'text',
					WebkitTextFillColor: 'transparent',
				}}>
					🔬 Spec-Driven Mode
				</div>
				<div style={{fontSize: 28, color: '#9ca3af', marginTop: 15}}>
					Multi-agent review with isolated worktrees
				</div>
			</div>

			{/* Workflow steps */}
			<div style={{display: 'flex', justifyContent: 'center', alignItems: 'center', gap: 30, marginBottom: 50}}>
				<WorkflowStep emoji="💡" label="Idea Explorer" opacity={step1Opacity} />
				<Arrow opacity={step1Opacity} />
				<WorkflowStep emoji="📝" label="Spec Writer" opacity={step2Opacity} />
				<Arrow opacity={step2Opacity} />
				<WorkflowStep emoji="🔍" label="Multi-Agent Review" opacity={step3Opacity} highlight />
				<Arrow opacity={step3Opacity} />
				<WorkflowStep emoji="🌿" label="Worktree" opacity={step4Opacity} />
			</div>

			{/* Reviewer Personas */}
			<div style={{opacity: personasOpacity, textAlign: 'center'}}>
				<div style={{fontSize: 28, color: '#ffffff', marginBottom: 25, fontWeight: 600}}>
					6 Built-in Reviewer Personas
				</div>
				<div style={{display: 'flex', justifyContent: 'center', gap: 20, flexWrap: 'wrap'}}>
					<Persona emoji="🏗️" name="Architect" />
					<Persona emoji="🔒" name="Paranoid Engineer" />
					<Persona emoji="⚙️" name="Operator" />
					<Persona emoji="✂️" name="Simplifier" />
					<Persona emoji="👤" name="User Advocate" />
					<Persona emoji="📊" name="Strategist" />
				</div>
			</div>
		</AbsoluteFill>
	);
};

const WorkflowStep: React.FC<{emoji: string; label: string; opacity: number; highlight?: boolean}> = ({
	emoji, label, opacity, highlight
}) => (
	<div style={{
		opacity,
		textAlign: 'center',
		backgroundColor: highlight ? 'rgba(147, 51, 234, 0.2)' : 'transparent',
		padding: highlight ? 20 : 10,
		borderRadius: 12,
		border: highlight ? '2px solid #9333ea' : 'none',
	}}>
		<div style={{fontSize: 48}}>{emoji}</div>
		<div style={{fontSize: 18, color: '#ffffff', fontWeight: 600, marginTop: 8}}>{label}</div>
	</div>
);

const Arrow: React.FC<{opacity: number}> = ({opacity}) => (
	<div style={{opacity, fontSize: 36, color: '#3b82f6'}}>→</div>
);

const Persona: React.FC<{emoji: string; name: string}> = ({emoji, name}) => (
	<div style={{
		backgroundColor: '#1e1e1e',
		borderRadius: 10,
		padding: '12px 20px',
		display: 'flex',
		alignItems: 'center',
		gap: 10,
	}}>
		<span style={{fontSize: 24}}>{emoji}</span>
		<span style={{fontSize: 18, color: '#ffffff'}}>{name}</span>
	</div>
);

// Scene 5: Outro
const OutroScene: React.FC = () => {
	const frame = useCurrentFrame();
	const {fps} = useVideoConfig();

	const urlOpacity = interpolate(frame, [0, 25], [0, 1], {extrapolateRight: 'clamp'});
	const ctaScale = spring({frame: Math.max(0, frame - 40), fps, config: {damping: 12}});
	const ctaOpacity = interpolate(frame, [40, 60], [0, 1], {extrapolateRight: 'clamp'});

	// Pulse effect for CTA
	const pulse = 1 + Math.sin(frame * 0.15) * 0.03;

	return (
		<AbsoluteFill style={{justifyContent: 'center', alignItems: 'center', backgroundColor: '#0a0a0a'}}>
			<div style={{textAlign: 'center'}}>
				{/* GitHub URL */}
				<div style={{
					opacity: urlOpacity,
					fontSize: 40,
					color: '#9333ea',
					fontFamily: 'monospace',
					marginBottom: 50,
				}}>
					github.com/Viniciuscarvalho/Feature-marker
				</div>

				{/* CTA */}
				<div style={{
					opacity: ctaOpacity,
					transform: `scale(${ctaScale * pulse})`,
				}}>
					<div style={{
						fontSize: 60,
						fontWeight: 'bold',
						background: 'linear-gradient(135deg, #9333ea 0%, #3b82f6 100%)',
						WebkitBackgroundClip: 'text',
						WebkitTextFillColor: 'transparent',
						marginBottom: 15,
					}}>
						Try v2.0 Today
					</div>
					<div style={{fontSize: 32, color: '#9ca3af'}}>
						Install in 30 seconds
					</div>
				</div>

				{/* Install command */}
				{frame >= 80 && (
					<div style={{
						marginTop: 50,
						backgroundColor: '#1e1e1e',
						padding: '25px 45px',
						borderRadius: 12,
						display: 'inline-block',
						opacity: interpolate(frame, [80, 100], [0, 1], {extrapolateRight: 'clamp'}),
					}}>
						<div style={{fontFamily: 'monospace', fontSize: 28, color: '#10b981'}}>
							$ ./feature-marker/install.sh
						</div>
					</div>
				)}
			</div>
		</AbsoluteFill>
	);
};
