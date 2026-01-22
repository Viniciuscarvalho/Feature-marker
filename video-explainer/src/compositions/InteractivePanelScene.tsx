import {AbsoluteFill, useCurrentFrame, interpolate} from 'remotion';

export const InteractivePanelScene: React.FC = () => {
	const frame = useCurrentFrame();

	// Panel slide in from left
	const panelX = interpolate(frame, [0, 40], [-1000, 0], {
		extrapolateRight: 'clamp',
	});

	// Options highlight sequentially
	const option1Highlight = frame >= 80 && frame < 200;
	const option2Highlight = frame >= 200 && frame < 350;
	const option3Highlight = frame >= 350 && frame < 500;

	// Descriptions fade in
	const desc1Opacity = interpolate(frame, [100, 120], [0, 1], {extrapolateRight: 'clamp'});
	const desc2Opacity = interpolate(frame, [220, 240], [0, 1], {extrapolateRight: 'clamp'});
	const desc3Opacity = interpolate(frame, [370, 390], [0, 1], {extrapolateRight: 'clamp'});

	return (
		<AbsoluteFill
			style={{
				backgroundColor: '#0a0a0a',
				justifyContent: 'center',
				alignItems: 'center',
			}}
		>
			{/* Interactive Panel */}
			<div
				style={{
					transform: `translateX(${panelX}px)`,
					backgroundColor: '#1e1e1e',
					borderRadius: 16,
					padding: 50,
					boxShadow: '0 25px 70px rgba(147, 51, 234, 0.3)',
					border: '2px solid #9333ea',
					minWidth: 800,
				}}
			>
				{/* Header */}
				<div
					style={{
						fontSize: 40,
						fontWeight: 'bold',
						color: '#ffffff',
						marginBottom: 40,
						textAlign: 'center',
						borderBottom: '2px solid #374151',
						paddingBottom: 20,
					}}
				>
					🚀 Feature Marker - Execution Mode
				</div>

				{/* Options */}
				<div style={{display: 'flex', flexDirection: 'column', gap: 30}}>
					<MenuOption
						number="1"
						title="Full Workflow"
						subtitle="Generate PRD/TechSpec/Tasks + Implementation"
						description="Creates missing files and executes all phases"
						isHighlighted={option1Highlight}
						descriptionOpacity={desc1Opacity}
					/>

					<MenuOption
						number="2"
						title="Tasks Only"
						subtitle="Skip generation, run implementation"
						description="Use existing PRD/TechSpec/Tasks (must exist)"
						isHighlighted={option2Highlight}
						descriptionOpacity={desc2Opacity}
					/>

					<MenuOption
						number="3"
						title="Ralph Loop Mode"
						subtitle="Autonomous loop execution"
						description="Uses ralph-wiggum for continuous iteration"
						isHighlighted={option3Highlight}
						descriptionOpacity={desc3Opacity}
					/>
				</div>
			</div>
		</AbsoluteFill>
	);
};

const MenuOption: React.FC<{
	number: string;
	title: string;
	subtitle: string;
	description: string;
	isHighlighted: boolean;
	descriptionOpacity: number;
}> = ({number, title, subtitle, description, isHighlighted, descriptionOpacity}) => (
	<div
		style={{
			backgroundColor: isHighlighted ? 'rgba(147, 51, 234, 0.2)' : 'transparent',
			border: isHighlighted ? '2px solid #9333ea' : '2px solid transparent',
			borderRadius: 12,
			padding: 20,
			transition: 'all 0.3s ease',
		}}
	>
		<div style={{display: 'flex', alignItems: 'flex-start', gap: 20}}>
			<div
				style={{
					fontSize: 32,
					fontWeight: 'bold',
					color: isHighlighted ? '#9333ea' : '#6b7280',
				}}
			>
				{number})
			</div>
			<div style={{flex: 1}}>
				<div
					style={{
						fontSize: 28,
						fontWeight: 'bold',
						color: '#ffffff',
						marginBottom: 5,
					}}
				>
					{title}
				</div>
				<div
					style={{
						fontSize: 20,
						color: '#9ca3af',
						marginBottom: 10,
					}}
				>
					{subtitle}
				</div>
				<div
					style={{
						fontSize: 18,
						color: '#6b7280',
						opacity: descriptionOpacity,
						fontStyle: 'italic',
					}}
				>
					→ {description}
				</div>
			</div>
		</div>
	</div>
);
