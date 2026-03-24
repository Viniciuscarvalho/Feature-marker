import {AbsoluteFill, Sequence} from 'remotion';
import {IntroScene} from './IntroScene';
import {BasicCommandScene} from './BasicCommandScene';
import {InteractivePanelScene} from './InteractivePanelScene';
import {WorkflowScene} from './WorkflowScene';
import {OutroScene} from './OutroScene';

export const MainVideo: React.FC = () => {
	return (
		<AbsoluteFill style={{backgroundColor: '#0a0a0a'}}>
			{/* Scene 1: Intro (0-6.6s) */}
			<Sequence from={0} durationInFrames={200}>
				<IntroScene />
			</Sequence>

			{/* Scene 2: Basic Command (6.6-13.3s) */}
			<Sequence from={200} durationInFrames={200}>
				<BasicCommandScene />
			</Sequence>

			{/* Scene 3: Interactive Panel (13.3-26.6s) */}
			<Sequence from={400} durationInFrames={400}>
				<InteractivePanelScene />
			</Sequence>

			{/* Scene 4: Workflow Execution (26.6-33.3s) */}
			<Sequence from={800} durationInFrames={200}>
				<WorkflowScene />
			</Sequence>

			{/* Scene 5: Outro (33.3-40s) */}
			<Sequence from={1000} durationInFrames={200}>
				<OutroScene />
			</Sequence>
		</AbsoluteFill>
	);
};
