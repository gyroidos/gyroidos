pipeline {
	agent any
	options { checkoutToSubdirectory('.manifests') }

	environment {
		YOCTO_VERSION = 'kirkstone'
	}

	parameters {
		choice(name: 'GYROID_ARCH', choices: ['x86', 'arm', 'arm64'], description: 'GyroidOS Target Architecture')
		choice(name: 'GYROID_MACHINE', choices: ['genericx86-64', 'apalis-imx8'], description: 'GyroidOS Target Machine (Must be compatible with GYROID_ARCH!)')
		string(name: 'PR_BRANCHES', defaultValue: '', description: 'Comma separated list of pull request branches (e.g. meta-trustx=PR-177,meta-trustx-nxp=PR-13,gyroidos_build=PR-97)')
		choice(name: 'BUILD_INSTALLER', choices: ['y', 'n'], description: 'Build the GyroidOS installer (x86 only)')
	}

	stages {
		stage('Repo') {
			steps {
				sh label: 'Clean workspace and repo init', script: '''
					#!/bin/bash
					echo "Running on $(hostname)"
					rm -fr ${WORKSPACE}/.repo ${WORKSPACE}/*

					env

					cd ${WORKSPACE}/.manifests
					git rev-parse --verify jenkins-ci && git branch -D jenkins-ci
					git checkout -b "jenkins-ci"
					cd ${WORKSPACE}

					repo init --depth=1 -u ${WORKSPACE}/.manifests/.git -b "jenkins-ci" -m yocto-${GYROID_ARCH}-${GYROID_MACHINE}.xml

					mkdir -p .repo/local_manifests

					branches="${PR_BRANCHES}"

					meta_repos="meta-trustx|meta-trustx-intel|meta-trustx-rpi|meta-trustx-nxp"
					cml_repo="cml"
					build_repo="gyroidos_build"
					branch_regex="PR-([0-9]+)"
					echo $branches | tr ',' '\n' | while read -r line; do
						if [[ "$line" =~ ($meta_repos)=$branch_regex ]]; then
							project="${BASH_REMATCH[1]}"
							revision="refs/pull/${BASH_REMATCH[2]}/head"

							echo "\
<?xml version=\\\"1.0\\\" encoding=\\\"UTF-8\\\"?>\n\
<manifest>\n\
<remove-project name=\\\"$project\\\" />\n\
<project path=\\\"$project\\\" name=\\\"$project\\\" remote=\\\"gyroidos\\\" revision=\\\"$revision\\\" />\n\
</manifest>" >> .repo/local_manifests/$project.xml
						elif [[ "$line" =~ ($cml_repo)=$branch_regex ]]; then
							project="${BASH_REMATCH[1]}"
							revision="refs/pull/${BASH_REMATCH[2]}/head"

							echo "\
<?xml version=\\\"1.0\\\" encoding=\\\"UTF-8\\\"?>\n\
<manifest>\n\
<remove-project name=\\\"$project\\\" />\n\
<project path=\\\"trustme/cml\\\" name=\\\"$project\\\" remote=\\\"gyroidos\\\" revision=\\\"$revision\\\" />\n\
</manifest>" >> .repo/local_manifests/$project.xml
						elif [[ "$line" =~ ($build_repo)=$branch_regex ]]; then
							project="${BASH_REMATCH[1]}"
							revision="refs/pull/${BASH_REMATCH[2]}/head"

							echo "\
<?xml version=\\\"1.0\\\" encoding=\\\"UTF-8\\\"?>\n\
<manifest>\n\
<remove-project name=\\\"$project\\\" />\n\
<project path=\\\"trustme/build\\\" name=\\\"$project\\\" remote=\\\"gyroidos\\\" revision=\\\"$revision\\\" />\n\
</manifest>" >> .repo/local_manifests/$project.xml
						fi
					done

					repo sync -j8 --current-branch --fail-fast
				'''

				stash includes: "meta-*/**, poky/**, trustme/**", name: 'ws-yocto', useDefaultExcludes: false, allowEmpty: false
				stash includes: ".manifests/**", name: 'manifests', useDefaultExcludes: false, allowEmpty: false
			}
		}

		stage('Build + Test Images') {
			// Build images in parallel
			matrix {
				axes {
					axis {
						name 'BUILDTYPE'
							values 'dev', 'production', 'ccmode', 'schsm'
					}
				}
				stages {
					stage('Build Image') {
						agent {
							dockerfile {
								dir ".manifests"
								args '--entrypoint=\'\' -v /yocto_mirror/${YOCTO_VERSION}/${GYROID_ARCH}/sources:/source_mirror -v /yocto_mirror/${YOCTO_VERSION}/${GYROID_ARCH}/sstate-cache:/sstate_mirror --env BUILDNODE="${env.NODE_NAME}"'
								reuseNode false
							}
						}
						steps {
							sh label: 'Clean up workspace', script: '''
								find "${WORKSPACE}" -exec rm -fr {} \\;

								echo "Running on host: ${NODE_NAME}"

									 ping -c1 8.8.8.8

                                     ping -c1 google.de

                                     wget https://www.yoctoproject.org/connectivity.html
							'''

                                                     
							unstash 'ws-yocto'
							sh label: 'Perform Yocto build', script: '''
								echo "Running on host: ${NODE_NAME}"
								export LC_ALL=en_US.UTF-8
								export LANG=en_US.UTF-8
								export LANGUAGE=en_US.UTF-8

								if [ "dev" = ${BUILDTYPE} ];then
									echo "Preparing Yocto workdir for development build"
									SANITIZERS=y
								elif [ "production" = "${BUILDTYPE}" ];then
									echo "Preparing Yocto workdir for production build"
									DEVELOPMENT_BUILD=n
								elif [ "ccmode" = "${BUILDTYPE}" ];then
									echo "Preparing Yocto workdir for CC Mode build"
									DEVELOPMENT_BUILD=n
									ENABLE_SCHSM="1"
									CC_MODE=y
								elif [ "schsm" = "${BUILDTYPE}" ];then
									echo "Preparing Yocto workdir for dev mode build with schsm support"
									SANITIZERS=y
									ENABLE_SCHSM="1"
								else
									echo "Error, unkown BUILDTYPE, exiting..."
									exit 1
								fi

								if [ -d out-${BUILDTYPE}/conf ]; then
									rm -r out-${BUILDTYPE}/conf
								fi

								. trustme/build/yocto/init_ws_ids.sh out-${BUILDTYPE} ${GYROID_ARCH} ${GYROID_MACHINE}

								cd ${WORKSPACE}/out-${BUILDTYPE}

								echo "INHERIT += \\\"own-mirrors\\\"" >> conf/local.conf
								echo "SOURCE_MIRROR_URL = \\\"file:///source_mirror\\\"" >> conf/local.conf
								echo "BB_GENERATE_MIRROR_TARBALLS = \\\"1\\\"" >> conf/local.conf

								echo "SSTATE_MIRRORS =+ \\\"file://.* file:///sstate_mirror/${BUILDTYPE}/PATH\\\"" >> conf/local.conf

								echo "BB_SIGNATURE_HANDLER = \\\"OEBasicHash\\\"" >> conf/local.conf
								echo "BB_HASHSERVE = \\\"\\\"" >> conf/local.conf

								cat conf/local.conf


								echo 'TRUSTME_DATAPART_EXTRA_SPACE="10000"' >> conf/local.conf

								bitbake trustx-cml-initramfs multiconfig:container:trustx-core
								bitbake trustx-cml

								if [ "y" = "${BUILD_INSTALLER}" ];then
									 bitbake multiconfig:installer:trustx-installer
								fi
							'''
						}
						post {
							success {
								script {
									if ("dev" == env.BUILDTYPE) {
										stash includes: "out-dev/tmp/deploy/images/**/trustme_image/trustmeimage.img, out-dev/test_certificates/**, trustme/build/**, trustme/cml/**", excludes: "**/oe-logs/**, **/oe-workdir/**", name: "img-dev"
									} else if ("production" == env.BUILDTYPE){
										stash includes: "out-production/tmp/deploy/images/**/trustme_image/trustmeimage.img, out-production/test_certificates/**, trustme/build/**, trustme/cml/**", excludes: "**/oe-logs/**, **/oe-workdir/**", name: "img-production"
									} else if("ccmode" == env.BUILDTYPE) {
										stash includes: "out-ccmode/tmp/deploy/images/**/trustme_image/trustmeimage.img, out-ccmode/test_certificates/**, trustme/build/**, trustme/cml/**", excludes: "**/oe-logs/**, **/oe-workdir/**", name: "img-ccmode"
									} else if("schsm" == env.BUILDTYPE) {
										stash includes: "out-schsm/tmp/deploy/images/**/trustme_image/trustmeimage.img, out-schsm/test_certificates/**, trustme/build/**, trustme/cml/**", excludes: "**/oe-logs/**, **/oe-workdir/**", name: "img-schsm"
									} else {
										error "Unkown build type"
									}
								}

								script {
									catchError(buildResult: 'SUCCESS', stageResult: 'UNSTABLE') {
										if (env.CHANGE_TARGET == null && PR_BRANCHES == "" && env.YOCTO_VERSION == env.BRANCH_NAME) {
											lock ('sync-mirror') {
												script {
													catchError(buildResult: 'SUCCESS', stageResult: 'UNSTABLE') {
														sh label: 'Syncing mirrors', script: '''
															if [ -d "/source_mirror" ];then
																rsync -r --ignore-existing --no-devices --no-specials --no-links  out-${BUILDTYPE}/downloads/ /source_mirror
															else
																echo "Skipping source_mirror sync, CHANGE_TARGET==${CHANGE_TARGET}, BRANCH_NAME==${BRANCH_NAME}, PR_BRANCHES==${PR_BRANCHES}, /source_mirror/: $(ls /source_mirror/)"
																exit 1
															fi

															if [ -d "/sstate_mirror" ];then
																rsync -r --no-devices --no-specials --no-links out-${BUILDTYPE}/sstate-cache/ /sstate_mirror/${BUILDTYPE}
															else
																echo "Skipping sstate_mirror sync, CHANGE_TARGET==${CHANGE_TARGET}, BRANCH_NAME==${BRANCH_NAME},  PR_BRANCHES==${PR_BRANCHES}, /sstate_mirror/${BUILDTYPE}: $(ls /sstate_mirror/)"
																exit 1
															fi

															exit 0
														'''
													}
												}
											}
										} else {
										echo "Skipping sstate cache sync in PR build CHANGE_TARGET==${env.CHANGE_TARGET}, BRANCH_NAME==${env.BRANCH_NAME}, PR_BRANCHES==${PR_BRANCHES},YOCTO_VERSION==${env.YOCTO_VERSION},"
										}
									}
								}

								sh label: 'Compress trustmeimage.img', script: 'xz -T 0 -f out-${BUILDTYPE}/tmp/deploy/images/**/trustme_image/trustmeimage.img --keep'

								script {
									if ("y" == env.BUILD_INSTALLER) {
										sh label: 'Compress trustmeinstaller.img', script: 'xz -T 0 -f out-${BUILDTYPE}/tmp/deploy/images/**/trustme_image/trustmeinstaller.img --keep'
									}
								}

								archiveArtifacts artifacts: 'out-**/tmp/deploy/images/**/trustme_image/trustmeimage.img.xz, out-**/tmp/deploy/images/**/trustme_image/trustmeinstaller.img.xz, out-**/test_certificates/**', fingerprint: true
							}
						}
					}
				}
			}
		}

		stage ('Integration Test') {
			when {
				expression {
					return "x86" == "${GYROID_ARCH}"
				}
			}

			matrix {
				axes {
					axis {
						name 'BUILDTYPE'
						values 'dev', 'production', 'ccmode'
					}
				}

				stages {
					stage('Integration Test') {
						agent {
							node { label 'worker' }
						}

						options {
							timeout(time: 30, unit: 'MINUTES')
						}

						steps {
							sh label: 'Clean workspace', script: 'rm -fr ${WORKSPACE}/.repo ${WORKSPACE}/*'

							script {
								if ("dev" == env.BUILDTYPE) {
									unstash 'img-dev'
								} else if ("production" == env.BUILDTYPE){
									unstash 'img-production'
								} else if ("ccmode" == env.BUILDTYPE){
									unstash 'img-ccmode'
								} else {
									error "Unkown build type"
								}
							}

							catchError(buildResult: 'FAILURE', stageResult: 'FAILURE') {
								sh label: 'Perform integration tests', script: '''
									echo "Running on node $(hostname)"
									echo "$PATH"

									export port_buildtype="$(expr $(printf "%d\n" "'${BUILDTYPE}") % 10)"

									if [ -z "${CHANGE_TARGET}" ];then
										echo "No PR-Build, using fixed port numbers"

										export ssh_port="222${port_buildtype}"
										export vnc_display="4${port_buildtype}"
									else
										echo "PR-Build, using port numbers based on PR"

										echo ${BRANCH_NAME}
										port_pr="$(echo -n "${BRANCH_NAME}" | sed 's/PR-\\([0-9]*\\)/\\1/g' | tail -c 2)"
										export ssh_port="2${port_pr}${port_buildtype}"
										export vnc_display="${port_pr}${port_buildtype}"
									fi
									
									echo "ssh_port: $ssh_port"
									echo "vnc_display: $vnc_display"
									echo "VM name: vm-$ssh_port"

									bash -c '${WORKSPACE}/trustme/cml/scripts/ci/VM-container-tests.sh --mode "${BUILDTYPE}" --skip-rootca --dir "${WORKSPACE}" --builddir "out-${BUILDTYPE}" --pki "${WORKSPACE}/out-${BUILDTYPE}/test_certificates" --name "vm-${BUILDTYPE}" --ssh "${ssh_port}" --kill --vnc "${vnc_display}" --log-dir "${WORKSPACE}/out-${BUILDTYPE}/cml_logs"'
								'''
							}

							echo "Archiving CML logs"
							archiveArtifacts artifacts: 'out-**/cml_logs/**, cml_logs/**', fingerprint: true, allowEmptyArchive: true

							script {
								if ('FAILURE' == currentBuild.result) {
									echo "Stage failed, exiting..."
									error('')
								}
							}
						}
					}
				}
			}
		}

		stage ('Token Test') {
			when {
				expression {
					return "x86" == "${GYROID_ARCH}"
				}
			}

			agent {
				node { label 'testing' }
			}

			steps {
				sh label: 'Clean workspace', script: 'rm -fr ${WORKSPACE}/.repo ${WORKSPACE}/meta-* ${WORKSPACE}/out-* ${WORKSPACE}/trustme/build ${WORKSPACE}/poky trustme/manifest'
				unstash 'img-schsm'
				lock ('schsm-test') {

					catchError(buildResult: 'FAILURE', stageResult: 'FAILURE') {
						sh label: 'Perform integration test with physical token', script: '''
							echo "Running on node $(hostname)"
							echo "$PATH"
							echo "Physhsm: ${PHYSHSM}"


							bash -c '${WORKSPACE}/trustme/cml/scripts/ci/VM-container-tests.sh --mode dev --dir ${WORKSPACE} --builddir out-schsm --pki "${WORKSPACE}/out-schsm/test_certificates" --name "${BRANCH_NAME}sc" --ssh 2231 --vnc 1 --kill --enable-schsm ${PHYSHSM} 12345678 --log-dir "${WORKSPACE}/out-schsm/cml_logs"'
						'''
					}

					echo "Archiving CML logs"
					archiveArtifacts artifacts: 'out-schsm/cml_logs', fingerprint: true, allowEmptyArchive: true

					script {
						if ('FAILURE' == currentBuild.result) {
							echo "Stage failed, exiting..."
							error('')
						}
					}
				}
			}
		}

		/*TODO deploy the development and production images on separate machines
		  and start demo applications inside them (e.g. a webserver)*/
		stage('Live Deployment') {
			parallel {
				stage('Development Image') {
					/*TODO;Skipped for now*/
					when {
						expression {
							/*If branch trustx master and comes from main repo?*/
							return false
						}
					}

					steps {
						sh 'echo pass'
					}
				}

				stage('Production Image') {
					/*TODO;Skipped for now*/
					when {
						expression {
							/*If branch trustx master and comes from main repo?*/
							return false
						}
					}
					steps {
						sh 'echo pass'
					}
				}
			}
		}

		stage('Documentation Generation') {
			/*TODO;Skipped for now*/
			when {
				expression {
					/*If branch trustx master and comes from main repo?*/
					return false
				}
			}

			steps {
				sh 'echo pass'
			}
		}
	}
}
